require "kemal"

module MJ
  # Shadowbox: compose mj's props/backdrops into a parallax depth-layer scene, then play it.
  # See notes/shadowbox-plan.md.
  #
  # NAME IS CENTRALISED HERE. The URL slug and display title live in these two constants and nowhere
  # else — routes and the nav derive from them. Renaming the tool (e.g. to "Diorama") is a one-line
  # change here plus renaming the .ecr/.js files; there is no hardcoded "shadowbox" scattered through
  # the routes or templates.
  module Shadowbox
    SLUG  = "shadowbox" # URL base + asset/scene namespace
    TITLE = "Shadowbox" # display name in the nav

    def self.slug : String
      SLUG
    end

    def self.title : String
      TITLE
    end

    def self.register
      # Editor.
      get "/#{SLUG}" do |env|
        render "src/views/shadowbox.ecr", "src/views/layout.ecr"
      end

      # Standalone player — a saved scene rendered chrome-less (no mj nav), embeddable. The scene
      # name is the last path segment; the player JS reads it from the URL and fetches the scene.
      get "/#{SLUG}/play/:name" do |env|
        render "src/views/shadowbox_player.ecr" # one arg → no layout wrapper
      end

      # Palette manifest: every placeable asset as {src,w,h,cut}. Props (cut-outs) come from the prop
      # library; backdrops (full frames) from the backdrop library. `src` is an mj-served /lib URL.
      get "/#{SLUG}/assets.json" do |env|
        env.response.content_type = "application/json"
        assets = [] of NamedTuple(src: String, w: Int32, h: Int32, cut: Bool, name: String)
        PropLibrary.load_manifest.props.each do |p|
          assets << {src: "/lib/props/#{p.name}.png", w: p.width, h: p.height, cut: true, name: p.name}
        end
        BackdropLibrary.list.each do |b|
          assets << {src: b.src, w: b.w, h: b.h, cut: false, name: b.name}
        end
        assets.to_json
      end

      # Library image serving — the libraries live OUTSIDE public/, so mj streams them. Names are
      # reduced to a basename AND the resolved path is checked to stay inside the library root, so no
      # crafted name (even one that basenames to "..") can escape.
      get "/lib/props/:name" do |env|
        raw = env.params.url["name"]
        name = File.basename(raw, File.extname(raw)) # strips dir + extension → the prop name
        dir = File.join(Config.props_dir, name)
        # Prefer the smaller .webp (mj webp) over the .png, transparently.
        webp = File.join(dir, "prop.webp")
        png = File.join(dir, "prop.png")
        if within?(Config.props_dir, webp) && File.file?(webp)
          send_file env, webp, "image/webp"
        elsif within?(Config.props_dir, png) && File.file?(png)
          send_file env, png, "image/png"
        else
          env.response.status_code = 404
          "not found"
        end
      end

      get "/lib/backdrops/:name" do |env|
        file = File.basename(env.params.url["name"]) # keep the extension; strip any dir
        base = File.basename(file, File.extname(file))
        webp = File.join(Config.backdrops_dir, base + ".webp")
        path = File.join(Config.backdrops_dir, file)
        if within?(Config.backdrops_dir, webp) && File.file?(webp)
          send_file env, webp, "image/webp"
        elsif within?(Config.backdrops_dir, path) && File.file?(path)
          send_file env, path
        else
          env.response.status_code = 404
          "not found"
        end
      end

      # Scene library — compositions saved by name. SceneLibrary.safe_name keeps every name inside
      # the root, so these need no extra traversal guard.
      get "/#{SLUG}/scenes" do |env|
        env.response.content_type = "application/json"
        SceneLibrary.list.to_json
      end

      get "/#{SLUG}/scenes/:name" do |env|
        if body = SceneLibrary.read(env.params.url["name"])
          env.response.content_type = "application/json"
          body
        else
          env.response.status_code = 404
          env.response.content_type = "application/json"
          %({"error":"not found"})
        end
      end

      put "/#{SLUG}/scenes/:name" do |env|
        env.response.content_type = "application/json"
        body = env.request.body.try(&.gets_to_end) || ""
        begin
          saved = SceneLibrary.save(env.params.url["name"], body)
          {saved: saved}.to_json
        rescue ex
          env.response.status_code = 400
          {error: ex.message}.to_json
        end
      end

      delete "/#{SLUG}/scenes/:name" do |env|
        env.response.content_type = "application/json"
        ok = SceneLibrary.delete(env.params.url["name"])
        env.response.status_code = 404 unless ok
        {deleted: ok}.to_json
      end
    end

    # True only if `path` resolves to somewhere inside `root` — the definitive traversal guard.
    private def self.within?(root : String, path : String) : Bool
      r = File.expand_path(root)
      p = File.expand_path(path)
      p == r || p.starts_with?(r + File::SEPARATOR)
    end
  end
end
