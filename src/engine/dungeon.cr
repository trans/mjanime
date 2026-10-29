require "json"
require "data_dungeon"

module MJ
  # mj's own DataDungeon store (Thomas, 2026-10-29: "your own data dungeon"). It holds what Thomas needs
  # to see or hear, with what mj measured of each (the listen checks, mouth cues, a roll's events) and,
  # once given, Thomas's answer. Not everything mj makes: the originals stay where they were made, and
  # anything here can be removed ("don't be too worried about using it for temporary storage").
  #
  # Each asset waiting for Thomas is linked `waiting-on` the name `thomas`, the link's data saying why.
  # Their answer replaces it with a `heard-by` link holding the answer and their note; a yes rates it 1, a
  # no rates it -1 and flags it, which puts it out of play. See docs/tools/dungeon.md.
  module Dungeon
    CONSUMER = "mj"
    WHO      = "thomas"
    WAITING  = "waiting-on"
    HEARD    = "heard-by"

    # The traits each type is looked up by, most important first; the first is the group. `piece` is
    # the outtake folder it was made in (landing-tour, bard-3, dice-roll).
    TYPES = {
      "speech" => %w[piece line subtype voice accent],
      "effect" => %w[piece sound],
    }

    RHUBARB = "rhubarb 1.14.0 --dialogFile"

    def self.dir : String
      ENV["MJ_DUNGEON_DIR"]?.presence || File.join(Config.xdg_data_home, "mj", "dungeon")
    end

    def self.open : DataDungeon::DB
      Dir.mkdir_p(dir)
      db = DataDungeon::DB.new(File.join(dir, "dungeon.db"), cache_root: File.join(dir, "objects"), consumer: CONSUMER)
      TYPES.each { |type, traits| db.register_type(type, pool_traits: traits, group_traits: traits.first(1)) }
      db
    end

    @@shared : DataDungeon::DB? = nil

    # One store kept open for `mj serve`.
    def self.shared : DataDungeon::DB
      @@shared ||= open
    end

    def self.open(& : DataDungeon::DB -> T) : T forall T
      db = open
      begin
        yield db
      ensure
        db.close
      end
    end

    # ---- adding ----------------------------------------------------------------------------------------------------

    # One thing to file, as a manifest gives it (`mj dungeon add <manifest.json>`): a JSON array of these.
    struct Entry
      include JSON::Serializable
      getter type : String
      getter file : String
      getter traits : Hash(String, String)
      # The asset in words: a take's words without its audio tags. Speech defaults to the `.txt` beside it.
      getter description : String?
      getter generator : String?
      # Rhubarb Lip Sync's JSON, kept as the `mouth` track.
      getter mouth : String?
      getter mouth_tool : String?
      # A JSON object of times in seconds (a roll's `shakes`, `first_knock`, …), kept as the `events` track.
      getter events : String?
      getter events_tool : String?
      getter recipe : RecipeEntry?
      # Why Thomas should see it. Nil files it without waiting on them.
      getter why : String?
    end

    struct RecipeEntry
      include JSON::Serializable
      getter form : String
      getter settings : Hash(String, JSON::Any) = {} of String => JSON::Any
      getter prompt : String?
      getter instructions : String?
      getter cost : Float64?
      getter cost_basis : String?
    end

    # Files each entry, and runs the listen checks on the speech among them (Whisper loaded once for
    # all; Gemini too unless `free`; none with `listen: false`). Filing the same bytes with the same traits again returns the asset
    # and refreshes its tracks, so a manifest can be run again. Returns the ids, in the entries' order.
    def self.add(db : DataDungeon::DB, entries : Array(Entry), free : Bool = false, listen : Bool = true) : Array(Int64)
      missing = entries.flat_map { |e| [e.file, e.mouth, e.events].compact }.reject { |f| File.file?(f) }
      raise ArgumentError.new("no such file: #{missing.join(", ")}") unless missing.empty?
      speech = entries.select { |e| e.type == "speech" }.map(&.file).uniq
      results = speech.empty? || !listen ? [] of Listen::Result : Listen.check(speech, free: free)
      checked = results.to_h { |r| {r.file, r} }
      entries.map do |e|
        rec = file(db, e)
        if (r = checked[e.file]?)
          db.set_track(rec.id, "listen", listen_cues(r), tool: listen_tool(r))
        end
        if (m = e.mouth)
          db.set_track(rec.id, "mouth", rhubarb_cues(m), tool: e.mouth_tool || RHUBARB)
        end
        if (ev = e.events)
          db.set_track(rec.id, "events", event_cues(ev), tool: e.events_tool || "mj")
        end
        if (why = e.why) && db.links_from(rec.id, HEARD).empty?
          db.link(rec.id, WAITING, WHO, {why: why, since: Time.local.to_s("%F")}.to_json)
        end
        rec.id
      end
    end

    private def self.file(db : DataDungeon::DB, e : Entry) : DataDungeon::AssetRecord
      words = e.description || (e.type == "speech" ? Listen.script_for(e.file, nil).try(&.[0]) : nil)
      tags = e.traits.merge({"take" => File.basename(e.file).sub(/\.[^.]+\z/, "")})
      recipe = e.recipe.try do |r|
        DataDungeon::Recipe.new(r.form, settings: r.settings, prompt: r.prompt, instructions: r.instructions,
          cost: r.cost, cost_basis: r.cost_basis)
      end
      db.store(e.type, tags, source_path: e.file, content_type: content_type(e.file),
        description: words.try { |w| spoken(w) }, generated: true, generator: e.generator,
        audio: audio_meta(e.file), made_at: File.info(e.file).modification_time, recipe: recipe)
    rescue ex : DataDungeon::AlreadyStored
      # The same bytes with the same traits come back as the asset; this is the same bytes under others.
      raise ArgumentError.new("#{e.file} is already asset #{ex.asset_id}#{" (retired)" if ex.retired?}, " \
                              "with other traits: remove it first, or file it as it is")
    end

    # The words as said: audio tags out, spaces closed up.
    def self.spoken(text : String) : String
      text.gsub(/\[[^\]]*\]/, " ").gsub(/\s+/, " ").strip
    end

    def self.content_type(path : String) : String
      case File.extname(path).downcase
      when ".mp3"  then "audio/mpeg"
      when ".wav"  then "audio/wav"
      when ".ogg"  then "audio/ogg"
      when ".flac" then "audio/flac"
      when ".m4a"  then "audio/mp4"
      else              raise ArgumentError.new("#{path}: not a sound mj files yet")
      end
    end

    # Length, rate, channels and bit rate, from ffprobe.
    def self.audio_meta(path : String) : DataDungeon::AudioMeta?
      buf = IO::Memory.new
      st = Process.run("ffprobe", ["-v", "error", "-show_entries", "format=duration,bit_rate:stream=sample_rate,channels",
                                   "-of", "json", path], output: buf)
      return nil unless st.success?
      j = JSON.parse(buf.to_s)
      stream = j["streams"]?.try(&.as_a.first?)
      DataDungeon::AudioMeta.new(
        duration_ms: j["format"]?.try(&.["duration"]?).try(&.as_s.to_f?).try { |s| (s * 1000).round.to_i },
        sample_rate: stream.try(&.["sample_rate"]?).try(&.as_s.to_i?),
        bitrate: j["format"]?.try(&.["bit_rate"]?).try(&.as_s.to_i?),
        channels: stream.try(&.["channels"]?).try(&.as_i?) || 1)
    end

    private def self.ms(seconds : Float64) : Int32
      (seconds * 1000).round.to_i
    end

    # The listen checks as cues, each read as `mj listen` prints it: each glitch over its time, each word
    # note at its time (the start, and no time in its words, when it has none). No cues means the checks
    # ran and found nothing.
    def self.listen_cues(r : Listen::Result) : Array(DataDungeon::TrackCue)
      cues = r.glitches.map do |f|
        DataDungeon::TrackCue.new(ms(f.time), ms(Math.max(f.until, f.time)), "#{f.time.round(2)} s, #{f.kind}: #{f.detail}")
      end
      r.words.each do |w|
        t = ms(w.time || 0.0)
        cues << DataDungeon::TrackCue.new(t, t, w.line(r.listeners))
      end
      cues.sort_by(&.start_ms)
    end

    def self.listen_tool(r : Listen::Result) : String
      who = r.listeners.map { |l| l == "Whisper" ? "Whisper small.en" : l == "Gemini" ? Listen::WORDS_MODEL : l }
      "mj listen #{VERSION} (glitches#{who.map { |w| ", #{w}" }.join})"
    end

    def self.rhubarb_cues(path : String) : Array(DataDungeon::TrackCue)
      JSON.parse(File.read(path))["mouthCues"].as_a.map do |c|
        DataDungeon::TrackCue.new(ms(c["start"].as_f), ms(c["end"].as_f), c["value"].as_s)
      end
    end

    # Every number, or list of numbers, in the object is a cue named by its key (`shakes` → `shake`,
    # `first_knock` → `first-knock`); `length` is the file's, not an event.
    def self.event_cues(path : String) : Array(DataDungeon::TrackCue)
      cues = [] of DataDungeon::TrackCue
      JSON.parse(File.read(path)).as_h.each do |k, v|
        next if k == "length"
        name = k.tr("_", "-")
        if (list = v.as_a?)
          name = name.chomp("s")
          list.each { |x| seconds(x).try { |s| cues << DataDungeon::TrackCue.new(ms(s), ms(s), name) } }
        elsif (s = seconds(v))
          cues << DataDungeon::TrackCue.new(ms(s), ms(s), name)
        end
      end
      cues.sort_by(&.start_ms)
    end

    private def self.seconds(x : JSON::Any) : Float64?
      x.as_f? || x.as_i64?.try(&.to_f)
    end

    # ---- Thomas's answers ------------------------------------------------------------------------------------------

    def self.heard(db : DataDungeon::DB, id : Int64, yes : Bool, note : String? = nil) : Nil
      raise ArgumentError.new("no asset #{id}") unless db.get_by_id(id, touch: false)
      db.unlink(id, WAITING, WHO)
      db.link(id, HEARD, WHO, {answer: yes ? "yes" : "no", note: note.presence, on: Time.local.to_s("%F")}.to_json)
      db.update_asset(id, rating: yes ? 1 : -1, flagged: !yes)
    end

    def self.remove(db : DataDungeon::DB, id : Int64) : Nil
      raise ArgumentError.new("no asset #{id}") unless db.get_by_id(id, touch: false)
      db.delete_asset(id)
    end

    # ---- reading ---------------------------------------------------------------------------------------------------

    # One asset as mj shows it, with its link to Thomas and its listen findings.
    struct Item
      include JSON::Serializable
      getter id : Int64
      getter type : String
      getter key : String?
      getter tags : Hash(String, String)
      getter take : String?
      getter piece : String?
      getter words : String?
      getter seconds : Float64?
      getter content_type : String
      getter why : String?
      getter since : String?
      getter answer : String?
      getter note : String?
      getter answered : String?
      getter listen : Array(String)?
      getter listen_tool : String?

      def initialize(@id, @type, @key, @tags, @words, @seconds, @content_type, @why, @since, @answer, @note,
                     @answered, @listen, @listen_tool)
        @take = @tags["take"]?
        @piece = @tags["piece"]?
      end

      def waiting? : Bool
        !@why.nil?
      end
    end

    def self.item(db : DataDungeon::DB, rec : DataDungeon::AssetRecord) : Item
      wait = db.links_from(rec.id, WAITING).find { |l| l.to_name == WHO }.try(&.data)
      heard = db.links_from(rec.id, HEARD).find { |l| l.to_name == WHO }.try(&.data)
      meta = db.get_with_meta_by_id(rec.id, touch: false).try(&.[1]).as?(DataDungeon::AudioMeta)
      track = db.track(rec.id, "listen")
      Item.new(rec.id, rec.asset_type, rec.key, db.load_tags(rec.id), rec.description,
        meta.try(&.duration_ms).try { |d| (d / 1000.0).round(2) }, rec.content_type,
        wait.try(&.["why"]?).try(&.as_s?), wait.try(&.["since"]?).try(&.as_s?),
        heard.try(&.["answer"]?).try(&.as_s?), heard.try(&.["note"]?).try(&.as_s?), heard.try(&.["on"]?).try(&.as_s?),
        track.try(&.cues.map(&.value)), track.try(&.tool))
    end

    def self.get(db : DataDungeon::DB, id : Int64) : Item?
      db.get_by_id(id, touch: false).try { |rec| item(db, rec) }
    end

    # What waits on Thomas, oldest filed first.
    def self.waiting(db : DataDungeon::DB) : Array(Item)
      db.list_assets(links: {WAITING => WHO}, limit: 1000).reverse.map { |rec| item(db, rec) }
    end

    # What they have answered, most recent filed first.
    def self.answered(db : DataDungeon::DB) : Array(Item)
      db.list_assets(links: {HEARD => WHO}, limit: 1000).map { |rec| item(db, rec) }
    end

    def self.everything(db : DataDungeon::DB) : Array(Item)
      db.list_assets(limit: 1000).reverse.map { |rec| item(db, rec) }
    end

    def self.print(items : Array(Item), io : IO = STDOUT) : Nil
      items.group_by(&.piece).each do |piece, group|
        io.puts "#{piece || "(no piece)"}:"
        group.each do |it|
          length = it.seconds ? " (#{it.seconds} s)" : ""
          io.puts "  #{it.id}  #{it.take || it.key}#{length}"
          io.puts "      \"#{it.words}\"" if it.words
          io.puts "      waiting since #{it.since}: #{it.why}" if it.why
          io.puts "      heard #{it.answered}: #{it.answer}#{it.note.try { |n| ", \"#{n}\"" }}" if it.answer
          it.listen.try(&.each { |l| io.puts "      listen: #{l}" })
        end
      end
    end
  end
end
