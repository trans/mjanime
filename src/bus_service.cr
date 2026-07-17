require "arcana-core"
require "base64"

module MJ
  # Exposes mj's image engines as a single multi-tool provider on the Arcana bus.
  # One address (`mj`), dispatch on the payload's `tool` field, `{"tool":"help"}`
  # returns the manifest. Runs a Client-backed Arcana::Toolset over the WebSocket
  # daemon (arcana-core >= 0.9).
  #
  # Every tool takes a source image via `input_path` (a file path) or `image_base64`,
  # and returns the result either written to `output_path` (returning {output_path})
  # or, if no output_path, inline as {image_base64, content_type}.
  module BusService
    PIXELIZE_SCHEMA = JSON.parse(%<{
      "type":"object",
      "properties":{
        "input_path":{"type":"string","description":"path to source image (or use image_base64)"},
        "image_base64":{"type":"string"},
        "style":{"type":"string","enum":["8bit","16bit"],"description":"pixel-art era (default 16bit)"},
        "background":{"type":"string","description":"transparent | keep | #RRGGBB (default transparent)"},
        "snap":{"type":"boolean","description":"pixel-perfect quantize pass (needs ImageMagick)"},
        "grid":{"type":"integer"},"colors":{"type":"integer"},
        "model":{"type":"string"},"width":{"type":"integer"},"height":{"type":"integer"},
        "output_path":{"type":"string","description":"write result here; omit for image_base64"}
      }
    }>)

    PROP_SCHEMA = JSON.parse(%<{
      "type":"object",
      "required":["prompt"],
      "properties":{
        "prompt":{"type":"string"},
        "input_path":{"type":"string","description":"template image path (or template_base64)"},
        "template_base64":{"type":"string"},
        "background":{"type":"array","items":{"type":"integer"},"description":"[r,g,b] bg to key out (default [0,0,0])"},
        "key_low":{"type":"integer"},"key_high":{"type":"integer"},"edge_blur":{"type":"integer"},
        "model":{"type":"string"},"width":{"type":"integer"},"height":{"type":"integer"},
        "output_path":{"type":"string"}
      }
    }>)

    SFX_SCHEMA = JSON.parse(%<{
      "type":"object",
      "properties":{
        "input_path":{"type":"string","description":"reference sound path (wav/mp3/...) — or use audio_base64"},
        "audio_base64":{"type":"string","description":"base64 of a wav/mp3 reference sound"},
        "preview_path":{"type":"string","description":"optional: render an approximation wav here"}
      }
    }>)

    DECORATE_SCHEMA = JSON.parse(%<{
      "type":"object",
      "required":["prompt"],
      "properties":{
        "prompt":{"type":"string","description":"the style / theme / details to apply"},
        "input_path":{"type":"string","description":"the master image path (or image_base64)"},
        "image_base64":{"type":"string"},
        "style_path":{"type":"string","description":"optional style-reference image path (or style_base64)"},
        "style_base64":{"type":"string"},
        "keep_structure":{"type":"boolean","description":"preserve the master's silhouette/layout (default true)"},
        "model":{"type":"string"},"width":{"type":"integer"},"height":{"type":"integer"},
        "output_path":{"type":"string"}
      }
    }>)

    BASE_SCHEMA = JSON.parse(%<{
      "type":"object",
      "required":["prompt"],
      "properties":{
        "prompt":{"type":"string"},
        "input_path":{"type":"string","description":"template image path (or template_base64)"},
        "template_base64":{"type":"string"},
        "strength":{"type":"number"},"steps":{"type":"integer"},"cfg_scale":{"type":"number"},
        "negative_prompt":{"type":"string"},"model":{"type":"string"},
        "output_path":{"type":"string"}
      }
    }>)

    # Standalone (`mj bus`): build, register, and block on the receive loop.
    def self.run
      Config.load!
      raise "RUNWARE_API_KEY not set" if Config.runware_api_key.empty?
      client = setup(RunwareClient.new(Config.runware_api_key))
      STDERR.puts "[bus] mj listening on #{bus_url} — tools: pixelize, prop, base"
      client.connect # blocks on the WebSocket receive loop
    end

    # Non-blocking (for `mj serve`): join the bus in a background fiber.
    # Degrades gracefully — a missing key or unreachable daemon logs and
    # leaves the web server running.
    def self.start_background
      Config.load!
      if Config.runware_api_key.empty?
        STDERR.puts "[bus] RUNWARE_API_KEY not set — bus tools disabled."
        return
      end
      client = setup(RunwareClient.new(Config.runware_api_key))
      spawn do
        begin
          STDERR.puts "[bus] mj joining #{bus_url} — tools: pixelize, prop, base"
          client.connect
        rescue ex
          STDERR.puts "[bus] disabled (#{ex.message})"
        end
      end
    end

    # Build the client + toolset and register the tools. Returns the client
    # (ts is kept alive by the on_message closure ts.start installs on it).
    private def self.setup(rw : RunwareClient) : Arcana::Client
      client = Arcana::Client.new(
        url: bus_url,
        address: "mj",
        name: "mj",
        description: "Media-jockey image studio — pixel-art restyle, transparent props, structural bases.",
        kind: Arcana::Directory::Kind::Service,
        capability: "image",
        tags: ["image", "pixel-art", "game-assets"],
      )
      ts = Arcana::Toolset.new(client: client, name: "mj",
        description: "Media-jockey image studio.")
      ts.tool("pixelize", "AI pixel-art restyle (8-bit/16-bit) of a reference image.",
        input_schema: PIXELIZE_SCHEMA) { |data| handle_pixelize(rw, data) }
      ts.tool("prop", "Generate a transparent 2D game prop from a rough flat-colour template.",
        input_schema: PROP_SCHEMA) { |data| handle_prop(rw, data) }
      ts.tool("base", "Generate a plain, structurally-faithful 'base' master from a template.",
        input_schema: BASE_SCHEMA) { |data| handle_base(rw, data) }
      ts.tool("decorate", "Stage 2: redraw a master image decorated in a given style/theme.",
        input_schema: DECORATE_SCHEMA) { |data| handle_decorate(rw, data) }
      ts.tool("sfx", "[EXPERIMENTAL] Fit a procedural Web Audio SFX recipe (JSON) from a reference sound. " \
              "Good on clean sustained/percussive sounds; a rough first pass on complex composites (e.g. water).",
        input_schema: SFX_SCHEMA) { |data| handle_sfx(data) }
      ts.start
      client
    end

    def self.bus_url : String
      if u = ENV["ARCANA_WS_URL"]?
        u
      elsif u = ENV["ARCANA_URL"]?
        u.sub(/^http/, "ws")
      else
        "ws://localhost:19118/bus"
      end
    end

    # --- tool handlers (JSON::Any request -> JSON::Any result) ---

    def self.handle_pixelize(rw : RunwareClient, data : JSON::Any) : JSON::Any
      src = source_bytes(data)
      spec = PixelSpec.from_yaml("{}")
      spec.style = data.str("style", spec.style)
      spec.model = data.str("model", spec.model)
      spec.prompt = data.str("prompt", spec.prompt)
      spec.snap = data.bool("snap", spec.snap)
      spec.grid = data.int("grid", spec.grid)
      spec.colors = data.int("colors", spec.colors)
      spec.background = data.str("background", spec.background)
      spec.width = data.int("width", spec.width)
      spec.height = data.int("height", spec.height)
      redraw = Pixelize.redraw(rw, src, spec)
      final = Pixelize.finish(redraw, spec)
      emit(CanvasUtil.to_png_bytes(final), data)
    end

    def self.handle_prop(rw : RunwareClient, data : JSON::Any) : JSON::Any
      prompt = data.str?("prompt") || raise "prop requires 'prompt'"
      src = source_bytes(data)
      spec = PropSpec.from_yaml({"prompt" => prompt}.to_yaml)
      spec.model = data.str("model", spec.model)
      if bg = data.arr?("background")
        spec.background = bg.map(&.as_i)
      end
      spec.key_low = data.int("key_low", spec.key_low)
      spec.key_high = data.int("key_high", spec.key_high)
      spec.edge_blur = data.int("edge_blur", spec.edge_blur)
      spec.width = data.int("width", spec.width)
      spec.height = data.int("height", spec.height)
      result = Prop.generate(rw, src, spec)
      emit(CanvasUtil.to_png_bytes(result.prop), data)
    end

    def self.handle_base(rw : RunwareClient, data : JSON::Any) : JSON::Any
      prompt = data.str?("prompt") || raise "base requires 'prompt'"
      src = source_bytes(data)
      spec = BaseSpec.from_yaml({"prompt" => prompt}.to_yaml)
      spec.model = data.str("model", spec.model)
      spec.strength = data.float("strength", spec.strength)
      spec.steps = data.int("steps", spec.steps)
      spec.cfg_scale = data.float("cfg_scale", spec.cfg_scale)
      spec.negative_prompt = data.str("negative_prompt", spec.negative_prompt)
      tmp = File.tempfile("mj-base", ".png")
      begin
        File.write(tmp.path, src)
        res = Base.generate(rw, tmp.path, spec)
        emit(res.image_data, data)
      ensure
        tmp.delete
      end
    end

    def self.handle_decorate(rw : RunwareClient, data : JSON::Any) : JSON::Any
      prompt = data.str?("prompt") || raise "decorate requires 'prompt'"
      src = source_bytes(data)
      spec = DecorateSpec.from_yaml({"prompt" => prompt}.to_yaml)
      spec.keep_structure = data.bool("keep_structure", spec.keep_structure)
      spec.model = data.str("model", spec.model)
      spec.width = data.int("width", spec.width)
      spec.height = data.int("height", spec.height)
      style = nil.as(Bytes?)
      if sp = data.str?("style_path")
        raise "style file not found: #{sp}" unless File.exists?(sp)
        style = File.read(sp).to_slice
      elsif sb = data.str?("style_base64")
        style = Base64.decode(sb)
      end
      emit(Decorate.generate(rw, src, spec, style), data)
    end

    def self.handle_sfx(data : JSON::Any) : JSON::Any
      tmp = nil.as(String?)
      wav = if p = data.str?("input_path")
              raise "audio file not found: #{p}" unless File.exists?(p)
              p
            elsif b64 = data.str?("audio_base64")
              tmp = File.tempname("mj_sfx_in", ".wav")
              File.write(tmp.not_nil!, Base64.decode(b64))
              tmp.not_nil!
            else
              raise "sfx requires input_path or audio_base64"
            end
      begin
        preview = data.str?("preview_path")
        recipe = Sfx.fit(wav, preview)
        result = {"recipe" => recipe} of String => JSON::Any
        result["preview_path"] = JSON::Any.new(preview) if preview
        JSON::Any.new(result)
      ensure
        if t = tmp
          File.delete(t) if File.exists?(t)
        end
      end
    end

    # --- io helpers ---

    def self.source_bytes(data : JSON::Any) : Bytes
      if path = (data.str?("input_path") || data.str?("template_path"))
        raise "source file not found: #{path}" unless File.exists?(path)
        File.read(path).to_slice
      elsif b64 = (data.str?("image_base64") || data.str?("template_base64"))
        Base64.decode(b64)
      else
        raise "missing source image: provide input_path (or image_base64)"
      end
    end

    def self.emit(bytes : Bytes, data : JSON::Any) : JSON::Any
      if path = data.str?("output_path")
        File.write(path, bytes)
        JSON::Any.new({"output_path" => JSON::Any.new(path)} of String => JSON::Any)
      else
        JSON::Any.new({
          "image_base64" => JSON::Any.new(Base64.strict_encode(bytes)),
          "content_type" => JSON::Any.new("image/png"),
        } of String => JSON::Any)
      end
    end
  end
end
