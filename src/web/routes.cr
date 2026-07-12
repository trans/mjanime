require "kemal"

module MJ
  module Routes
    def self.register
      # -- Dashboard --
      get "/" do |env|
        cuts = CutStore.list_cuts
        render "src/views/index.ecr", "src/views/layout.ecr"
      end

      # -- New cut form --
      get "/cuts/new" do |env|
        render "src/views/cuts/new.ecr", "src/views/layout.ecr"
      end

      # -- Create cut --
      post "/cuts" do |env|
        name = env.params.body["name"].as(String)
        slug = name.downcase.gsub(/[^a-z0-9]+/, "-").strip("-")

        cut = CutStore.create_cut(slug, name)
        cut_path = CutStore.cut_path(slug)

        if file = env.params.files["reference"]?
          dest = File.join(cut_path, "reference.png")
          File.copy(file.tempfile.path, dest)
        end

        env.redirect "/cuts/#{slug}"
      end

      # -- Cut workspace --
      get "/cuts/:slug" do |env|
        slug = env.params.url["slug"]
        cut = CutStore.get_cut(slug)
        cut_path = CutStore.cut_path(slug)
        script_path = File.join(cut_path, "script.yml")

        script_content = File.exists?(script_path) ? File.read(script_path) : ""
        has_reference = File.exists?(File.join(cut_path, "reference.png"))
        cut_id = cut.try(&.id) || 0_i64
        frame_numbers = FrameStore.new.list_frames(cut_id)
        job = nil.as(RenderJob?)

        render "src/views/cuts/show.ecr", "src/views/layout.ecr"
      end

      # -- Save script --
      put "/cuts/:slug/script" do |env|
        slug = env.params.url["slug"]
        content = env.params.body["script_content"].as(String)

        begin
          MotionScript.from_yaml(content)
          script_path = File.join(CutStore.cut_path(slug), "script.yml")
          File.write(script_path, content)
          "Script saved."
        rescue ex : YAML::ParseException
          env.response.status_code = 422
          "YAML error: #{ex.message}"
        end
      end

      # -- Start render --
      post "/cuts/:slug/render" do |env|
        slug = env.params.url["slug"]
        script_path = File.join(CutStore.cut_path(slug), "script.yml")
        script_content = File.read(script_path)
        script = MotionScript.from_yaml(script_content)

        STDERR.puts "[render] Script loaded: #{script.title} (#{script.total_frames} frames, strength=#{script.settings.strength})"
        script.scenes.each do |scene|
          if frames = scene.frames
            frames.each_with_index do |f, i|
              STDERR.puts "[render]   Frame #{i + 1}: #{f.prompt}"
            end
          elsif keyframes = scene.keyframes
            keyframes.each do |kf|
              STDERR.puts "[render]   Keyframe #{kf.frame}: #{kf.prompt || "(interpolated)"}"
            end
          end
        end

        job_id = App.renderer.start_render(slug, script)
        env.redirect "/cuts/#{slug}/render/#{job_id}"
      end

      # -- Render status page --
      get "/cuts/:slug/render/:job_id" do |env|
        slug = env.params.url["slug"]
        job_id = env.params.url["job_id"]
        job = App.renderer.get_job(job_id)
        cut = CutStore.get_cut(slug)
        cut_path = CutStore.cut_path(slug)
        script_path = File.join(cut_path, "script.yml")
        script_content = File.exists?(script_path) ? File.read(script_path) : ""
        has_reference = File.exists?(File.join(cut_path, "reference.png"))
        cut_id = cut.try(&.id) || 0_i64
        frame_numbers = FrameStore.new.list_frames(cut_id)

        render "src/views/cuts/show.ecr", "src/views/layout.ecr"
      end

      # -- Render status HTMX partial --
      get "/cuts/:slug/render/:job_id/status" do |env|
        job_id = env.params.url["job_id"]
        job = App.renderer.get_job(job_id)
        render "src/views/render/status.ecr"
      end

      # -- Frame gallery HTMX partial --
      get "/cuts/:slug/frames" do |env|
        slug = env.params.url["slug"]
        cut_id = CutStore.get_cut_id(slug) || 0_i64
        frame_numbers = FrameStore.new.list_frames(cut_id)
        render "src/views/frames/gallery.ecr"
      end

      # -- Frame detail HTMX partial --
      get "/cuts/:slug/frames/:number" do |env|
        slug = env.params.url["slug"]
        number = env.params.url["number"].to_i
        cut_id = CutStore.get_cut_id(slug) || 0_i64
        metadata = FrameStore.new.load_frame_metadata(cut_id, number)
        render "src/views/frames/detail.ecr"
      end

      # -- Serve frame image --
      get "/cuts/:slug/frames/:number/image" do |env|
        slug = env.params.url["slug"]
        number = env.params.url["number"].to_i
        path = File.join(CutStore.cut_path(slug), "frames", "%04d.png" % number)

        if File.exists?(path)
          env.response.content_type = "image/png"
          File.read(path)
        else
          env.response.status_code = 404
          "Frame not found"
        end
      end

      # -- Serve reference image --
      get "/cuts/:slug/reference" do |env|
        slug = env.params.url["slug"]
        path = File.join(CutStore.cut_path(slug), "reference.png")

        if File.exists?(path)
          env.response.content_type = "image/png"
          File.read(path)
        else
          env.response.status_code = 404
          "Reference image not found"
        end
      end

      # -- Extract pose from reference image --
      post "/cuts/:slug/extract-pose" do |env|
        slug = env.params.url["slug"]
        cut_path = CutStore.cut_path(slug)
        reference_path = File.join(cut_path, "reference.png")

        env.response.content_type = "application/json"

        unless File.exists?(reference_path)
          env.response.status_code = 400
          next {error: "No reference image"}.to_json
        end

        begin
          client = RunwareClient.new(Config.runware_api_key)
          ref_uuid = client.upload_image(reference_path)
          guide_uuid, guide_url = client.preprocess_pose(ref_uuid, 512, 512)

          # Download and save the skeleton image
          pose_response = HTTP::Client.get(guide_url)
          if pose_response.status_code == 200
            File.write(File.join(cut_path, "base_pose.png"), pose_response.body)
          end

          # Save the guide UUID for later use
          File.write(File.join(cut_path, "pose_guide_uuid.txt"), guide_uuid)

          {status: "ok", guide_uuid: guide_uuid, guide_url: guide_url}.to_json
        rescue ex
          STDERR.puts "[pose] Extract error: #{ex.message}"
          env.response.status_code = 500
          {error: ex.message}.to_json
        end
      end

      # -- Serve base pose skeleton image --
      get "/cuts/:slug/pose/skeleton" do |env|
        slug = env.params.url["slug"]
        path = File.join(CutStore.cut_path(slug), "base_pose.png")

        if File.exists?(path)
          env.response.content_type = "image/png"
          File.read(path)
        else
          env.response.status_code = 404
          "No pose extracted yet"
        end
      end

      # -- Save pose JSON --
      put "/cuts/:slug/pose" do |env|
        slug = env.params.url["slug"]
        cut_path = CutStore.cut_path(slug)
        pose_json = env.request.body.try(&.gets_to_end) || ""

        begin
          Pose.from_json(pose_json)
          File.write(File.join(cut_path, "base_pose.json"), pose_json)
          env.response.content_type = "application/json"
          {status: "ok"}.to_json
        rescue ex
          env.response.status_code = 422
          {error: ex.message}.to_json
        end
      end

      # -- Get pose JSON --
      get "/cuts/:slug/pose" do |env|
        slug = env.params.url["slug"]
        path = File.join(CutStore.cut_path(slug), "base_pose.json")

        if File.exists?(path)
          env.response.content_type = "application/json"
          File.read(path)
        else
          env.response.status_code = 404
          {error: "No pose data"}.to_json
        end
      end

      # -- Render a pose skeleton preview from JSON --
      post "/cuts/:slug/pose/preview" do |env|
        slug = env.params.url["slug"]
        pose_json = env.request.body.try(&.gets_to_end) || ""
        pose = Pose.from_json(pose_json)
        png_bytes = PoseRenderer.render(pose, 512, 512)
        env.response.content_type = "image/png"
        String.new(png_bytes)
      end

      # -- Regenerate single frame --
      post "/cuts/:slug/frames/:number/regenerate" do |env|
        slug = env.params.url["slug"]
        number = env.params.url["number"].to_i
        cut_path = CutStore.cut_path(slug)
        cut_id = CutStore.get_cut_id(slug)
        raise "Cut not found" unless cut_id
        script_path = File.join(cut_path, "script.yml")
        script = MotionScript.from_yaml(File.read(script_path))

        generator = RunwareClient.new(Config.runware_api_key)
        store = FrameStore.new
        chain = FrameChain.new(generator, store)

        spawn do
          chain.render_single(cut_path, cut_id, script, number)
        end

        env.redirect "/cuts/#{slug}"
      end
    end
  end
end
