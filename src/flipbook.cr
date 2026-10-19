require "kemal"
require "json"
require "digest/sha256"

module MJ
  # Flipbook: lay out the frames already made, put them in an order, and play them, so a person can
  # see which pictures move into one another cleanly and say which are unusable.
  #
  # A frame is any folder under the outtake root holding a keyed `prop.png` drawn on the shared
  # stage (848x1264 for the Bard), so frames line up when played. Each frame gets a number the first
  # time it's seen and keeps it, so it can be referred to by number. What the person decides (unusable
  # frames, notes, named sequences) is saved in the outtake root's `flipbook.json`, where an agent can
  # read it.
  module Flipbook
    SLUG  = "flipbook"
    TITLE = "Flipbook"
    SIZES = {"thumb" => 150, "view" => 600}

    def self.slug : String
      SLUG
    end

    def self.title : String
      TITLE
    end

    # The frames live in the project's outtake/, next to where mj is served from.
    def self.root : String
      ENV["MJ_FLIPBOOK_ROOT"]? || File.join(Dir.current, "outtake")
    end

    def self.state_path : String
      File.join(root, "flipbook.json")
    end

    def self.cache_dir : String
      File.join(ENV["HOME"], ".local", "share", "mj", "flipbook-cache")
    end

    def self.load_state : JSON::Any
      return JSON.parse(%({})) unless File.exists?(state_path)
      JSON.parse(File.read(state_path))
    end

    def self.save_state(h : Hash(String, JSON::Any))
      tmp = state_path + ".tmp"
      File.write(tmp, JSON::Any.new(h).to_pretty_json)
      File.rename(tmp, state_path)
    end

    # Every frame folder under the root, numbered: a new folder takes the next number, and a number,
    # once given, stays with its folder.
    @@paths_at : Time::Instant? = nil
    @@paths = {} of Int64 => String

    # The path of frame `n`, from a listing at most a few seconds old: thumbnails come in by the
    # hundred, and each needn't scan the folders again.
    def self.path_of(n : Int64) : String?
      now = Time.instant
      last = @@paths_at
      if last.nil? || now - last > 5.seconds
        _, list = frames
        @@paths = list.to_h { |f| {f[:n], f[:path]} }
        @@paths_at = now
      end
      @@paths[n]?
    end

    def self.frames : {Hash(String, JSON::Any), Array(NamedTuple(n: Int64, path: String))}
      state = load_state.as_h? || {} of String => JSON::Any
      numbers = state["numbers"]?.try(&.as_h?) || {} of String => JSON::Any
      next_n = state["next"]?.try(&.as_i64?) || 1_i64
      paths = Dir.glob(File.join(root, "*", "**", "prop.png")).map { |p| File.dirname(p)[root.size + 1..] }.sort
      changed = false
      paths.each do |p|
        next if numbers.has_key?(p)
        numbers[p] = JSON::Any.new(next_n)
        next_n += 1
        changed = true
      end
      state["numbers"] = JSON::Any.new(numbers)
      state["next"] = JSON::Any.new(next_n)
      save_state(state) if changed
      list = paths.map { |p| {n: numbers[p].as_i64, path: p} }
      {state, list}
    end

    def self.register
      get "/#{SLUG}" do |env|
        render "src/views/flipbook.ecr", "src/views/layout.ecr"
      end

      # The frames, and what has been decided about them.
      get "/#{SLUG}/frames.json" do |env|
        env.response.content_type = "application/json"
        state, list = frames
        {
          frames:    list.map { |f|
            v = File.info?(File.join(root, f[:path], "prop.png")).try(&.modification_time.to_unix) || 0
            {n: f[:n], path: f[:path], group: f[:path].split('/').first, v: v}
          },
          unusable:  state["unusable"]? || JSON::Any.new([] of JSON::Any),
          notes:     state["notes"]? || JSON::Any.new({} of String => JSON::Any),
          sequences: state["sequences"]? || JSON::Any.new({} of String => JSON::Any),
        }.to_json
      end

      # A frame's picture by number, at thumb or view height, as a cached webp.
      get "/#{SLUG}/img/:n/:size" do |env|
        n = env.params.url["n"].to_i64?
        height = SIZES[env.params.url["size"]]?
        path = n ? path_of(n) : nil
        src = path ? File.join(root, path, "prop.png") : ""
        if height.nil? || path.nil? || !within?(root, src) || !File.file?(src)
          env.response.status_code = 404
          next "no such frame"
        end
        Dir.mkdir_p(cache_dir)
        key = Digest::SHA256.hexdigest("#{src}|#{File.info(src).modification_time.to_unix}|#{height}")[0, 20]
        webp = File.join(cache_dir, "#{key}.webp")
        unless File.exists?(webp)
          tmp = webp + ".tmp.webp"
          status = Process.run("magick", [src, "-resize", "x#{height}", "-quality", "85",
                                          "-define", "webp:alpha-quality=100", tmp])
          unless status.success?
            env.response.status_code = 500
            next "magick failed"
          end
          File.rename(tmp, webp)
        end
        env.response.headers["Cache-Control"] = "max-age=3600"
        send_file env, webp, "image/webp"
      end

      # Save what the person decided: unusable frames, notes, sequences. The numbers are the server's.
      post "/#{SLUG}/state" do |env|
        env.response.content_type = "application/json"
        body = JSON.parse(env.request.body.try(&.gets_to_end) || "{}")
        state, _ = frames
        %w(unusable notes sequences).each do |k|
          state[k] = body[k] if body.as_h.has_key?(k)
        end
        save_state(state)
        {ok: true}.to_json
      end
    end

    private def self.within?(root : String, path : String) : Bool
      r = File.expand_path(root)
      p = File.expand_path(path)
      p == r || p.starts_with?(r + File::SEPARATOR)
    end
  end
end
