require "json"
require "digest/sha256"
require "base64"
require "http/client"

module MJ
  # Checks on a recorded voice take, shaped by the listen test (outtake `listen-test/README.md`, 2026-10-29). That
  # test asked Gemini about 28 clips whose answers were known (planted faults, Thomas's past calls), and found what a
  # model that hears audio can and can't be trusted with:
  #
  # - **Glitches are measured, not asked about.** Gemini 3.1 Pro found 2 of 8 planted clicks, cuts, dropouts and
  #   clipped stretches, and a different two when it thought harder. The four measurements in `Glitch` find every
  #   planted fault they cover and nothing in mj's 339 real voice takes. Their thresholds were set between the two.
  # - **Words go to two listeners.** Whisper (local, free) and Gemini 3.8 Flash each transcribe the take, and each is
  #   compared with the script. A word both hear differently is worth a person's ear; a word only one hears
  #   differently is more likely that listener. On the Scottish tour takes Whisper misheard two lines Gemini got right,
  #   and both heard u-4's "like a hotel" as "what's a hotel".
  # - **Processing is judged against a reference.** Given the original, Gemini 3.1 Pro called all five pitch-shifted
  #   Henrys processed (11 of 12 right); given a take alone, neither model heard any pitch shift.
  #
  # Not offered, because both models got it wrong: whether two takes are the same speaker.
  # The prompts are the test's own, word for word, since they are what was measured.
  module Listen
    SR = 24_000

    # USD per 1M tokens (input, output with thinking), Google's published rates on 2026-10-29. Google reports tokens,
    # not prices, so the ledger's figure is computed; a model not listed here is logged unpriced.
    RATES = {
      "gemini-3.8-flash"       => {0.75, 3.75}, # introductory, through 2026-12-31
      "gemini-3.1-pro-preview" => {2.0, 12.0},
    }
    WORDS_MODEL   = "gemini-3.8-flash"
    COMPARE_MODEL = "gemini-3.1-pro-preview"

    # ---- decoding --------------------------------------------------------------------------------------------------

    # Any file ffmpeg reads, as mono SR samples in -1..1.
    def self.decode(path : String) : Array(Float32)
      got = IO::Memory.new
      err = IO::Memory.new
      status = begin
        Process.run("ffmpeg", ["-v", "error", "-i", path, "-ac", "1", "-ar", SR.to_s, "-f", "s16le", "-"],
          output: got, error: err)
      rescue File::NotFoundError
        raise "mj listen needs ffmpeg on PATH."
      end
      raise "ffmpeg couldn't read #{path}: #{err.to_s.strip}" unless status.success?
      got.rewind
      Array(Float32).new(got.size // 2) { got.read_bytes(Int16, IO::ByteFormat::LittleEndian).to_f32 / 32768 }
    end

    # ---- glitches --------------------------------------------------------------------------------------------------

    record Finding, time : Float64, kind : String, detail : String, until : Float64 = 0.0 do
      include JSON::Serializable
    end

    # The four measurements. Every threshold sits between the strongest value in mj's 339 real takes and the weakest
    # planted fault (listen-test/glitch/), and is absolute, not relative to the take: they were set on ElevenLabs takes
    # peaking near -1 dBFS, so a much quieter take is checked less sensitively. What they can't catch: a cut that
    # happens to land where the waveform meets itself (one of the two planted cuts), or a glitch that is a sound in
    # its own right, such as a garbled syllable.
    module Glitch
      # A click: a 1-3 ms burst whose high-frequency energy is 25 times its 50 ms surroundings' and whose sample-to-
      # sample step reaches 1.0. The steepest consonant in the real takes stepped 0.81; the planted clicks 1.45.
      CLICK_RATIO = 25.0
      CLICK_STEP  =  1.0
      # A hard cut: one sample-to-sample step of 0.7 or more, 10 times the steps round it. Real takes reached 0.58;
      # the planted cut that landed mid-swing 0.86.
      CUT_STEP  = 0.7
      CUT_RATIO = 10.0
      # A dropout: 20 ms or more of digital silence, inside the take, that the voice drops into from full volume (the
      # 10 ms before it at an RMS of 0.1 or more). Speech fades into its pauses: the loudest lead-in to a real take's
      # silence was 0.063; the planted dropouts' 0.28. A voice starting at full volume after a silence isn't counted:
      # two of the Kokoro voice tests do that.
      DROP_QUIET = 0.001
      DROP_MS    =    20
      DROP_EDGE  =   0.1
      # Clipping: flat tops, four or more equal samples above 0.2, twenty or more of them within 50 ms of each other.
      # Real takes had at most 5 in a cluster; the planted clipping 61 to 363.
      FLAT_LEVEL =   0.2
      FLAT_TOL   = 2e-4
      FLAT_MIN   =   20

      def self.find(x : Array(Float32)) : Array(Finding)
        (clicks(x) + cuts(x) + dropouts(x) + clipping(x)).sort_by(&.time).tap { |found| merge_cut_into_click!(found) }
      end

      # A click is also a big step, and so is a clipped stretch's edge; say each once, as the click or the clipping.
      private def self.merge_cut_into_click!(found : Array(Finding)) : Nil
        clicks = found.select { |f| f.kind == "click" }
        clipped = found.select { |f| f.kind == "clipping" }.map { |f| {f.time, f.until} }
        found.reject! do |f|
          f.kind == "cut" && (clicks.any? { |c| (c.time - f.time).abs < 0.01 } ||
                              clipped.any? { |a, b| a - 0.05 <= f.time <= b + 0.05 })
        end
      end

      def self.clicks(x : Array(Float32)) : Array(Finding)
        w = SR // 1000
        n = (x.size - 1) // w
        e = Array(Float64).new(n) do |f|
          s = 0.0
          w.times { |k| i = f * w + k; d = (x[i + 1] - x[i]).to_f; s += d * d }
          s / w
        end
        found = [] of Finding
        buf = [] of Float64
        f = 0
        while f < n
          a = Math.max(0, f - 25)
          b = Math.min(n, f + 26)
          buf.clear
          (a...b).each { |k| buf << e[k] }
          buf.sort!
          med = Math.max(buf[buf.size // 2], 1e-7)
          if e[f] > 1e-4 && e[f] > CLICK_RATIO * med
            j = f
            while j < n && e[j] > CLICK_RATIO * med
              j += 1
            end
            if j - f <= 3
              step = 0.0
              lo = f * w
              hi = Math.min(x.size - 1, lo + 3 * w)
              (lo...hi).each { |i| step = Math.max(step, (x[i + 1] - x[i]).abs.to_f) }
              if step >= CLICK_STEP
                found << Finding.new(f / 1000.0, "click",
                  "a #{j - f} ms burst, #{(e[f] / med).round.to_i} times as bright as round it (step #{step.round(2)})")
              end
            end
            f = j
          else
            f += 1
          end
        end
        found
      end

      def self.cuts(x : Array(Float32)) : Array(Finding)
        d = Array(Float64).new(x.size - 1) { |i| (x[i + 1] - x[i]).abs.to_f }
        sq = Array(Float64).new(d.size + 1, 0.0)
        d.each_with_index { |v, i| sq[i + 1] = sq[i] + v * v }
        w = SR * 5 // 1000
        g = SR // 2000
        found = [] of Finding
        last = -SR
        d.each_with_index do |v, i|
          next unless v >= CUT_STEP && i - last > SR // 20
          a = Math.max(0, i - w)
          b = Math.min(d.size, i + w)
          l = Math.max(i - g, a)
          r = Math.min(i + g + 1, b)
          count = (l - a) + (b - r)
          next if count <= 0
          rms = Math.sqrt(((sq[l] - sq[a]) + (sq[b] - sq[r])) / count)
          if v > CUT_RATIO * Math.max(rms, 1e-4)
            found << Finding.new(i / SR.to_f, "cut", "the waveform jumps by #{v.round(2)}, as at a hard splice")
            last = i
          end
        end
        found
      end

      def self.dropouts(x : Array(Float32)) : Array(Finding)
        w = SR // 1000
        n = x.size // w
        quiet = Array(Bool).new(n) { |f| (0...w).all? { |k| x[f * w + k].abs < DROP_QUIET } }
        found = [] of Finding
        f = 0
        while f < n
          unless quiet[f]
            f += 1
            next
          end
          j = f
          while j < n && quiet[j]
            j += 1
          end
          if j - f >= DROP_MS && f > 0 && j < n
            pre = rms(x, Math.max(0, (f - 10) * w), f * w)
            if pre >= DROP_EDGE
              found << Finding.new(f / 1000.0, "dropout", "#{j - f} ms of silence inside the take; the voice stops dead")
            end
          end
          f = j
        end
        found
      end

      def self.clipping(x : Array(Float32)) : Array(Finding)
        hits = [] of Float64
        i = 0
        last = x.size - 1
        while i < last
          if flat?(x, i)
            j = i
            while j < last && flat?(x, j)
              j += 1
            end
            hits << i / SR.to_f if j - i >= 3
            i = j
          else
            i += 1
          end
        end
        groups = [] of {Float64, Float64, Int32}
        hits.each do |t|
          if (g = groups.last?) && t - g[1] < 0.05
            groups[-1] = {g[0], t, g[2] + 1}
          else
            groups << {t, t, 1}
          end
        end
        groups.select { |g| g[2] >= FLAT_MIN }.map do |a, b, c|
          Finding.new(a, "clipping", "#{c} flat tops from #{a.round(2)} to #{b.round(2)} s", b)
        end
      end

      private def self.flat?(x : Array(Float32), i : Int32) : Bool
        (x[i + 1] - x[i]).abs < FLAT_TOL && x[i + 1].abs > FLAT_LEVEL
      end

      private def self.rms(x : Array(Float32), a : Int32, b : Int32) : Float64
        return 0.0 if b <= a
        s = 0.0
        (a...b).each { |i| s += x[i].to_f * x[i] }
        Math.sqrt(s / (b - a))
      end
    end

    # ---- words -----------------------------------------------------------------------------------------------------

    # A word as compared: `text` lower case, letters and digits only ("Don't" -> "dont"); `shown` as written; `time`
    # when the listener heard it, where it says.
    record Token, text : String, shown : String, time : Float64? = nil

    # One place a listener's words leave the script: the script's words from `at` (none for an insertion before `at`),
    # and what the listener heard instead, from its word `from` (none for a dropped word).
    record Diff, at : Int32, script : Array(Token), from : Int32, heard : Array(Token)

    # Words, with any audio tags ([strong Scottish accent], [chuckles]) taken out.
    def self.tokens(text : String, time : Float64? = nil) : Array(Token)
      text.gsub(/\[[^\]]*\]/, " ").scan(/[A-Za-z0-9]+(?:['’][A-Za-z0-9]+)*/).map do |m|
        Token.new(m[0].downcase.gsub(/['’]/, ""), m[0], time)
      end
    end

    # Number words a listener may write in digits: "forty" heard as "40" is the word as written.
    NUMBERS = {"0" => "zero", "1" => "one", "2" => "two", "3" => "three", "4" => "four", "5" => "five", "6" => "six",
               "7" => "seven", "8" => "eight", "9" => "nine", "10" => "ten", "11" => "eleven", "12" => "twelve",
               "13" => "thirteen", "14" => "fourteen", "15" => "fifteen", "16" => "sixteen", "17" => "seventeen",
               "18" => "eighteen", "19" => "nineteen", "20" => "twenty", "30" => "thirty", "40" => "forty",
               "50" => "fifty", "60" => "sixty", "70" => "seventy", "80" => "eighty", "90" => "ninety"}

    # Equal (a number in words or digits), or one letter apart in a word of five or more: "jewelled" and "jeweled"
    # are the same word heard; "roll" and "roar" aren't.
    def self.same_word?(a : String, b : String) : Bool
      return true if a == b || NUMBERS[a]? == b || NUMBERS[b]? == a
      a.size >= 5 && b.size >= 5 && (a.size - b.size).abs <= 1 && levenshtein(a, b) <= 1
    end

    def self.levenshtein(a : String, b : String) : Int32
      prev = (0..b.size).to_a
      a.each_char_with_index do |ca, i|
        cur = [i + 1]
        b.each_char_with_index do |cb, j|
          cur << Math.min(Math.min(cur[j] + 1, prev[j + 1] + 1), prev[j] + (ca == cb ? 0 : 1))
        end
        prev = cur
      end
      prev[b.size]
    end

    # Where `heard` leaves `script`, by the longest common run of words.
    def self.diff(script : Array(Token), heard : Array(Token)) : Array(Diff)
      m, n = script.size, heard.size
      l = Array.new(m + 1) { Array(Int32).new(n + 1, 0) }
      (m - 1).downto(0) do |i|
        (n - 1).downto(0) do |j|
          l[i][j] = same_word?(script[i].text, heard[j].text) ? l[i + 1][j + 1] + 1 : Math.max(l[i + 1][j], l[i][j + 1])
        end
      end
      diffs = [] of Diff
      i = j = 0
      gs, gh = 0, 0
      flush = ->(si : Int32, hj : Int32) do
        if si > gs || hj > gh
          diffs << Diff.new(gs, script[gs...si], gh, heard[gh...hj])
        end
      end
      while i < m && j < n
        if same_word?(script[i].text, heard[j].text)
          flush.call(i, j)
          i += 1
          j += 1
          gs, gh = i, j
        elsif l[i + 1][j] >= l[i][j + 1]
          i += 1
        else
          j += 1
        end
      end
      flush.call(m, n)
      diffs.reject { |d| spelling?(d, script, heard) }
    end

    # A difference in spelling, not hearing: the same letters split or joined ("em bark" for "Embark"), or a word
    # split off its neighbour ("a while" for "awhile", where "while" matched "awhile").
    def self.spelling?(d : Diff, script : Array(Token), heard : Array(Token)) : Bool
      s = d.script.join(&.text)
      h = d.heard.join(&.text)
      return true if !s.empty? && s == h
      before = ->(list : Array(Token), i : Int32) { i > 0 ? list[i - 1]?.try(&.text) : nil }
      if d.script.empty?
        after_s, after_h = script[d.at]?.try(&.text), heard[d.from + d.heard.size]?.try(&.text)
        return true if after_s && after_h && h + after_h == after_s
        before_s, before_h = before.call(script, d.at), before.call(heard, d.from)
        return true if before_s && before_h && before_h + h == before_s
      elsif d.heard.empty?
        after_s, after_h = script[d.at + d.script.size]?.try(&.text), heard[d.from]?.try(&.text)
        return true if after_s && after_h && s + after_s == after_h
        before_s, before_h = before.call(script, d.at), before.call(heard, d.from)
        return true if before_s && before_h && before_s + s == before_h
      end
      false
    end

    # Where in Whisper's words a place in the script falls, given where Whisper left the script: that word's time.
    private def self.aligned_time(at : Int32, dw : Array(Diff), whisper : Array(Token)) : Float64?
      i = at + dw.select { |d| d.at + d.script.size <= at }.sum { |d| d.heard.size - d.script.size }
      i >= 0 ? whisper[i]?.try(&.time) : nil
    end

    # Whisper on every file at once (one model load), through uv so faster-whisper needn't be installed. Returns each
    # file's words with times, or nil for all when uv or the model isn't there.
    WHISPER_PY = {{ read_file("#{__DIR__}/listen_whisper.py") }}

    def self.whisper(paths : Array(String)) : Hash(String, Array(Token))?
      return Hash(String, Array(Token)).new if paths.empty?
      script = File.tempname("mj_listen_whisper", ".py")
      File.write(script, WHISPER_PY)
      got = IO::Memory.new
      err = IO::Memory.new
      status = begin
        Process.run("uv", ["run", "-q", "--with", "faster-whisper", "python", "-I", script] + paths, output: got, error: err)
      rescue File::NotFoundError
        STDERR.puts "[listen] Whisper skipped: uv isn't on PATH"
        return nil
      ensure
        File.delete?(script)
      end
      unless status.success?
        STDERR.puts "[listen] Whisper failed: #{err.to_s.strip.lines.last?}"
        return nil
      end
      result = Hash(String, Array(Token)).new
      got.to_s.each_line do |line|
        j = JSON.parse(line)
        result[j["file"].as_s] = j["words"].as_a.flat_map do |w|
          tokens(w["w"].as_s, w["t"].as_f? || w["t"].as_i.to_f)
        end
      end
      result
    end

    # ---- Gemini ----------------------------------------------------------------------------------------------------

    # The test's prompt for one clip. Only the transcript and accent are read from its answer: what it says about
    # glitches and processing is what the test found unreliable.
    SINGLE = <<-TXT
      You are checking a recorded voice line for a game before a person listens to it. Listen to the whole recording carefully and answer only from what you hear. Where you can't tell, answer "unsure".

      A glitch is any of: a click or pop; a cut, where part of a word is missing or the audio jumps; a dropout, a moment of silence inside a word; distortion or clipping. Ordinary breaths, pauses between words and intended vocal effects are not glitches.

      Answer in JSON with exactly these keys:
      - "glitch": "yes", "no" or "unsure"
      - "glitches": a list of {"time_s": seconds from the start, "kind": "click", "cut", "dropout", "distortion" or "other"}, empty if none
      - "accent": the speaker's accent in a few words
      - "scottish": "yes", "no" or "unsure": is the accent Scottish throughout?
      - "processed": "yes", "no" or "unsure": does the voice sound artificially pitch-shifted, sped up or otherwise processed?
      - "natural": "yes", "no" or "unsure": does it sound like a natural human performance?
      - "transcript": the words spoken
      - "note": one short sentence on anything a director should know
      TXT

    # The test's prompt for a take against a reference. Only "processed" and the note are reported: its pitch and pace
    # answers mixed the two up, and its same-speaker answers were wrong.
    PAIR = <<-TXT
      Recording A is the reference. Recording B is the take being checked. Compare B with A, answering only from what you hear. Where you can't tell, answer "unsure".

      Answer in JSON with exactly these keys:
      - "same_speaker": "yes", "no" or "unsure": is B the same person's voice as A?
      - "pitch": "higher", "lower", "same" or "unsure": B's voice pitch compared with A's
      - "speed": "faster", "slower", "same" or "unsure": B's speaking pace compared with A's
      - "processed": "yes", "no" or "unsure": does B sound artificially pitch-shifted, sped up or otherwise processed, compared with A?
      - "note": one short sentence on the difference you hear
      TXT

    def self.api_key : String?
      ENV["GEMINI_API_KEY"]? || ENV["GOOGLE_API_KEY"]?
    end

    # The audio as Gemini takes it: WAV at SR, so every file goes the same way whatever it came as.
    private def self.audio_part(path : String) : JSON::Any
      got = IO::Memory.new
      err = IO::Memory.new
      status = Process.run("ffmpeg", ["-v", "error", "-i", path, "-ac", "1", "-ar", SR.to_s, "-f", "wav", "-"],
        output: got, error: err)
      raise "ffmpeg couldn't read #{path}: #{err.to_s.strip}" unless status.success?
      JSON.parse({inlineData: {mimeType: "audio/wav", data: Base64.strict_encode(got.to_slice)}}.to_json)
    end

    private def self.text_part(text : String) : JSON::Any
      JSON.parse({text: text}.to_json)
    end

    def self.ask(model : String, parts : Array(JSON::Any), key : String) : JSON::Any
      body = {
        contents:         [{role: "user", parts: parts}],
        generationConfig: {responseMimeType: "application/json", thinkingConfig: {thinkingLevel: "low"}},
      }.to_json
      cached = cache_path(model, body)
      return JSON.parse(File.read(cached)) if cached && File.file?(cached)
      headers = HTTP::Headers{"Content-Type" => "application/json", "x-goog-api-key" => key}
      problem = ""
      # An overloaded service, or an answer that isn't JSON (now and then an empty one), is asked again.
      3.times do |attempt|
        sleep (2 ** attempt).seconds if attempt > 0
        r = HTTP::Client.post("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent",
          headers: headers, body: body)
        unless r.status_code == 200
          problem = "Gemini error (#{r.status_code}): #{r.body[0, 300]}"
          next if MJ::Retry.retryable?(r.status_code, r.body)
          raise problem
        end
        parsed = JSON.parse(r.body)
        MJ::Spend.record("listen", model, cost(model, parsed["usageMetadata"]?), provider: "google")
        candidate = parsed["candidates"]?.try(&.[0]?)
        text = candidate.try(&.["content"]?).try(&.["parts"]?).try(&.as_a?).try do |ps|
          ps.reject { |p| p["thought"]?.try(&.as_bool?) }.join { |p| p["text"]?.try(&.as_s?) || "" }
        end || ""
        text = text.strip.lchop("```json").lchop("```").rchop("```").strip
        begin
          answer = JSON.parse(text)
          if cached
            Dir.mkdir_p(File.dirname(cached))
            File.write(cached, answer.to_json)
          end
          return answer
        rescue ex : JSON::ParseException
          why = candidate.try(&.["finishReason"]?).try(&.as_s?)
          problem = "Gemini answered something that isn't JSON#{" (#{why})" if why}: #{text.empty? ? "nothing" : text[0, 120].inspect}"
        end
      end
      raise problem
    end

    # Each answer is kept by the request's SHA-256 (the model, the audio and the question), so asking the same
    # again (filing a manifest again) costs nothing. `MJ_LISTEN_CACHE=0` turns it off.
    private def self.cache_path(model : String, body : String) : String?
      return nil if ENV["MJ_LISTEN_CACHE"]? == "0"
      base = ENV["XDG_CACHE_HOME"]?.presence || File.join(Path.home.to_s, ".cache")
      File.join(base, "mj", "listen", Digest::SHA256.hexdigest("#{model}\n#{body}") + ".json")
    end

    private def self.cost(model : String, usage : JSON::Any?) : Float64?
      rate = RATES[model]?
      return nil unless rate && usage
      tin = usage["promptTokenCount"]?.try(&.as_i?) || 0
      tout = (usage["candidatesTokenCount"]?.try(&.as_i?) || 0) + (usage["thoughtsTokenCount"]?.try(&.as_i?) || 0)
      (tin * rate[0] + tout * rate[1]) / 1_000_000.0
    end

    def self.gemini_words(path : String, key : String) : JSON::Any
      ask(WORDS_MODEL, [audio_part(path), text_part(SINGLE)], key)
    end

    def self.gemini_compare(path : String, ref : String, key : String) : JSON::Any
      ask(COMPARE_MODEL, [text_part("Recording A:"), audio_part(ref), text_part("Recording B:"), audio_part(path),
                          text_part(PAIR)], key)
    end

    # ---- the report ------------------------------------------------------------------------------------------------

    # One place the words differ from the script, as both listeners heard it. `whisper` and `gemini` are what each
    # heard there, nil where it heard the script (or didn't listen).
    struct WordNote
      include JSON::Serializable
      getter script : String
      getter whisper : String?
      getter gemini : String?
      getter time : Float64?

      def initialize(@script, @whisper, @gemini, @time)
      end

      def both? : Bool
        !@whisper.nil? && !@gemini.nil?
      end

      # `"Like" at 3.3 s: Whisper heard "What's", Gemini heard "what's" (both: worth a listen)`, given the
      # listeners that ran.
      def line(listeners : Array(String), at : Bool = true) : String
        where = @script.empty? ? "nothing written" : "\"#{@script}\""
        where += " at #{@time.not_nil!.round(2)} s" if at && @time
        heard = [@whisper.try { |s| "Whisper heard \"#{s}\"" }, @gemini.try { |s| "Gemini heard \"#{s}\"" }].compact.join(", ")
        verdict = if both?
                    "both: worth a listen"
                  elsif listeners.size > 1
                    "only #{@whisper ? "Whisper" : "Gemini"}"
                  else
                    "one listener"
                  end
        "#{where}: #{heard} (#{verdict})"
      end
    end

    struct Result
      include JSON::Serializable
      getter file : String
      getter duration : Float64
      getter glitches : Array(Finding)
      getter script : String?
      getter script_from : String?
      getter listeners : Array(String)
      getter words : Array(WordNote)
      getter whisper_heard : String?
      getter gemini_heard : String?
      getter accent : String?
      getter scottish : String?
      getter ref : String?
      getter processed : String?
      getter processed_note : String?

      def initialize(@file, @duration, @glitches, @script, @script_from, @listeners, @words, @whisper_heard,
                     @gemini_heard, @accent, @scottish, @ref, @processed, @processed_note)
      end
    end

    # The script for a take: the one given, or the `.txt` beside it with the same name (as outtake `landing-tour/`
    # keeps them), else none.
    def self.script_for(take : String, given : String?) : {String, String}?
      return {given, "the given script"} if given
      txt = take.sub(/\.[^.\/]+\z/, ".txt")
      File.file?(txt) ? {File.read(txt).strip, File.basename(txt)} : nil
    end

    def self.notes(script : Array(Token), whisper : Array(Token)?, gemini : Array(Token)?) : Array(WordNote)
      dw = whisper ? diff(script, whisper) : [] of Diff
      dg = gemini ? diff(script, gemini) : [] of Diff
      said = ->(d : Diff) { d.heard.empty? ? "(nothing)" : d.heard.map(&.shown).join(" ") }
      span = ->(d : Diff) { {d.at, d.at + Math.max(d.script.size, 1)} }
      got = [] of {Int32, WordNote}
      taken = Set(Int32).new
      dw.each do |a|
        ra = span.call(a)
        gi = dg.each_index.find { |k| !taken.includes?(k) && (rb = span.call(dg[k]); rb[0] < ra[1] && ra[0] < rb[1]) }
        b = gi ? dg[gi] : nil
        taken << gi if gi
        lo = b ? Math.min(a.at, b.at) : a.at
        hi = b ? Math.max(a.at + a.script.size, b.at + b.script.size) : a.at + a.script.size
        time = a.heard.first?.try(&.time) || (a.from > 0 ? whisper.not_nil![a.from - 1].time : nil)
        got << {lo, WordNote.new(script[lo...hi].map(&.shown).join(" "), said.call(a), b.try { |x| said.call(x) }, time)}
      end
      dg.each_with_index do |b, k|
        next if taken.includes?(k)
        got << {b.at, WordNote.new(b.script.map(&.shown).join(" "), nil, said.call(b), whisper.try { |w| aligned_time(b.at, dw, w) })}
      end
      got.sort_by(&.[0]).map(&.[1])
    end

    # One take's Gemini answer, or nil (said on stderr) when it didn't come, so the other takes and the free
    # checks still report.
    private def self.gemini_or_nil(take : String, & : -> JSON::Any) : JSON::Any?
      yield
    rescue ex
      STDERR.puts "[listen] #{File.basename(take)}: no Gemini answer, so Whisper alone: #{ex.message}"
      nil
    end

    # `free`: no Gemini (glitches and Whisper only). `glitches_only`: the measurements alone, no listener.
    def self.check(takes : Array(String), script : String? = nil, ref : String? = nil, free : Bool = false,
                   glitches_only : Bool = false) : Array(Result)
      key = free || glitches_only ? nil : api_key
      STDERR.puts "[listen] no GEMINI_API_KEY in the environment, so only the free checks" if !(free || glitches_only) && key.nil?
      scripts = takes.to_h { |t| {t, glitches_only ? nil : script_for(t, script)} }
      heard = whisper(takes.select { |t| scripts[t] }) || Hash(String, Array(Token)).new
      takes.map do |t|
        x = decode(t)
        sc = scripts[t]
        g = key ? gemini_or_nil(t) { gemini_words(t, key.not_nil!) } : nil
        gemini_tokens = g.try(&.["transcript"]?).try(&.as_s?).try { |s| tokens(s) }
        listeners = [] of String
        listeners << "Whisper" if heard.has_key?(t)
        listeners << "Gemini" if gemini_tokens
        words = sc ? notes(tokens(sc[0]), heard[t]?, gemini_tokens) : [] of WordNote
        cmp = key && ref && ref != t ? gemini_or_nil(t) { gemini_compare(t, ref.not_nil!, key.not_nil!) } : nil
        Result.new(t, (x.size / SR.to_f).round(2), Glitch.find(x), sc.try(&.[0]), sc.try(&.[1]), listeners, words,
          heard[t]?.try(&.map(&.shown).join(" ")), g.try(&.["transcript"]?).try(&.as_s?),
          g.try(&.["accent"]?).try(&.as_s?), g.try(&.["scottish"]?).try(&.as_s?),
          cmp ? ref : nil, cmp.try(&.["processed"]?).try(&.as_s?), cmp.try(&.["note"]?).try(&.as_s?))
      end
    end

    def self.print(results : Array(Result), io : IO = STDOUT) : Nil
      results.each_with_index do |r, n|
        io.puts if n > 0
        io.puts "#{r.file} (#{r.duration} s)"
        if r.glitches.empty?
          io.puts "  glitches: none found (clicks, hard cuts, dropouts, clipping)"
        else
          io.puts "  glitches:"
          r.glitches.each { |f| io.puts "    #{f.time.round(2)} s, #{f.kind}: #{f.detail}" }
        end
        if r.script
          who = r.listeners.join(" and ")
          if r.listeners.empty?
            io.puts "  words: not checked (no listener ran)"
          elsif r.words.empty?
            io.puts "  words: as written in #{r.script_from} (#{who})"
          else
            io.puts "  words, against #{r.script_from} (#{who}):"
            r.words.each { |w| io.puts "    #{w.line(r.listeners)}" }
          end
        elsif (g = r.gemini_heard)
          io.puts "  words (no script): Gemini heard \"#{g}\""
        end
        if (a = r.accent)
          io.puts "  accent (Gemini): #{a}; Scottish throughout: #{r.scottish || "?"}"
        end
        if (ref = r.ref)
          io.puts "  against #{ref} (Gemini 3.1 Pro): processed #{r.processed || "?"}. #{r.processed_note}"
        end
      end
    end
  end
end
