module Minanime
  class FrameChain
    def initialize(@generator : Generator, @store : FrameStore)
    end

    # Legacy prompt-based render (no ControlNet)
    def render(cut_path : String, cut_id : Int64, script : MotionScript, &block : Int32, Int32 ->)
      reference_path = File.join(cut_path, "reference.png")
      raise "Reference image not found: #{reference_path}" unless File.exists?(reference_path)

      if script.uses_poses?
        render_with_poses(cut_path, cut_id, script, reference_path, &block)
      else
        render_with_prompts(cut_path, cut_id, script, reference_path, &block)
      end
    end

    # Prompt-based render (original approach)
    private def render_with_prompts(cut_path : String, cut_id : Int64, script : MotionScript, reference_path : String, &block : Int32, Int32 ->)
      current_seed = reference_path
      current_seed_is_uuid = false
      frame_number = 0

      script.scenes.each do |scene|
        next unless frames = scene.frames
        frames.each do |frame_spec|
          frame_number += 1

          request = GenerationRequest.new(
            prompt: frame_spec.prompt,
            seed_image: current_seed,
            seed_is_uuid: current_seed_is_uuid,
            width: frame_spec.width || script.settings.width,
            height: frame_spec.height || script.settings.height,
            model: frame_spec.model || script.settings.model,
            strength: frame_spec.strength || script.settings.strength,
            steps: frame_spec.steps || script.settings.steps,
            cfg_scale: frame_spec.cfg_scale || script.settings.cfg_scale
          )

          start_time = Time.instant
          result = @generator.generate(request)
          elapsed_ms = (Time.instant - start_time).total_milliseconds.to_i64

          metadata = FrameMetadata.new(
            frame_number: frame_number,
            scene: scene.name,
            prompt: frame_spec.prompt,
            seed_image: current_seed_is_uuid ? current_seed : "reference",
            model: frame_spec.model || script.settings.model,
            strength: frame_spec.strength || script.settings.strength,
            width: frame_spec.width || script.settings.width,
            height: frame_spec.height || script.settings.height,
            task_uuid: result.response_id || "",
            generated_at: Time.utc,
            generation_time_ms: elapsed_ms,
            api_response_id: result.response_id
          )

          @store.save_frame(cut_path, cut_id, frame_number, result.image_data, metadata)

          if uuid = result.image_uuid
            current_seed = uuid
            current_seed_is_uuid = true
          else
            current_seed = File.join(cut_path, "frames", "%04d.png" % frame_number)
            current_seed_is_uuid = false
          end

          yield frame_number, script.total_frames
        end
      end
    end

    # Pose-based render with ControlNet
    private def render_with_poses(cut_path : String, cut_id : Int64, script : MotionScript, reference_path : String, &block : Int32, Int32 ->)
      cn_model = script.settings.controlnet_model
      raise "controlnet_model required for pose-based scripts" unless cn_model

      # Need a RunwareClient for preprocessing
      client = @generator.as(RunwareClient)

      # Upload reference and extract base pose
      STDERR.puts "[pose] Uploading reference for pose extraction..."
      ref_uuid = client.upload_image(reference_path)

      STDERR.puts "[pose] Extracting base pose from reference..."
      guide_uuid, guide_url = client.preprocess_pose(ref_uuid, script.settings.width, script.settings.height)

      # Download the pose skeleton image for reference
      pose_skeleton_path = File.join(cut_path, "base_pose.png")
      pose_response = HTTP::Client.get(guide_url)
      if pose_response.status_code == 200
        File.write(pose_skeleton_path, pose_response.body)
        STDERR.puts "[pose] Base pose skeleton saved to #{pose_skeleton_path}"
      end

      # Load base pose JSON if available, otherwise create empty
      base_pose_path = File.join(cut_path, "base_pose.json")
      base_pose = if File.exists?(base_pose_path)
                    Pose.from_json(File.read(base_pose_path))
                  else
                    Pose.new
                  end

      current_seed = ref_uuid
      current_seed_is_uuid = true
      global_frame = 0

      script.scenes.each do |scene|
        keyframes = scene.keyframes
        next unless keyframes && !keyframes.empty?

        scene_total = scene.total_frames || keyframes.last.frame

        # Build interpolated frames for this scene
        (1..scene_total).each do |scene_frame|
          global_frame += 1

          # Find surrounding keyframes for interpolation
          before = keyframes.select { |kf| kf.frame <= scene_frame }.last?
          after = keyframes.select { |kf| kf.frame >= scene_frame }.first?

          # Determine prompt (from nearest keyframe)
          prompt = (before.try(&.prompt) || after.try(&.prompt) || "")
          strength = before.try(&.strength) || script.settings.strength

          # Interpolate pose
          frame_pose = if before && after && before.frame != after.frame
                         t = (scene_frame - before.frame).to_f / (after.frame - before.frame)
                         pose_a = before.joints ? base_pose.with_overrides(before.joints.not_nil!) : base_pose
                         pose_b = after.joints ? base_pose.with_overrides(after.joints.not_nil!) : base_pose
                         Pose.interpolate(pose_a, pose_b, t)
                       elsif before && before.joints
                         base_pose.with_overrides(before.joints.not_nil!)
                       elsif after && after.joints
                         base_pose.with_overrides(after.joints.not_nil!)
                       else
                         base_pose
                       end

          # Render the pose skeleton to PNG
          skeleton_bytes = PoseRenderer.render(frame_pose, script.settings.width, script.settings.height)

          # Upload skeleton as guide image
          STDERR.puts "[pose] Frame #{global_frame}: uploading pose skeleton..."
          skeleton_uuid = client.upload_image_bytes(skeleton_bytes)

          # Build ControlNet params
          cn_param = ControlNetParam.new(
            model: cn_model,
            guide_image: skeleton_uuid,
            weight: script.settings.controlnet_weight,
            start_step: 0,
            end_step: script.settings.steps,
            control_mode: "balanced"
          )

          request = GenerationRequest.new(
            prompt: prompt,
            seed_image: current_seed,
            seed_is_uuid: current_seed_is_uuid,
            width: script.settings.width,
            height: script.settings.height,
            model: script.settings.model,
            strength: strength,
            steps: script.settings.steps,
            cfg_scale: script.settings.cfg_scale,
            controlnet: [cn_param]
          )

          start_time = Time.instant
          result = @generator.generate(request)
          elapsed_ms = (Time.instant - start_time).total_milliseconds.to_i64

          metadata = FrameMetadata.new(
            frame_number: global_frame,
            scene: scene.name,
            prompt: prompt,
            seed_image: current_seed_is_uuid ? current_seed : "reference",
            model: script.settings.model,
            strength: strength,
            width: script.settings.width,
            height: script.settings.height,
            task_uuid: result.response_id || "",
            generated_at: Time.utc,
            generation_time_ms: elapsed_ms,
            api_response_id: result.response_id
          )

          @store.save_frame(cut_path, cut_id, global_frame, result.image_data, metadata)

          # Save the skeleton frame too for debugging
          skeleton_dir = File.join(cut_path, "skeletons")
          Dir.mkdir_p(skeleton_dir)
          File.write(File.join(skeleton_dir, "%04d.png" % global_frame), skeleton_bytes)

          if uuid = result.image_uuid
            current_seed = uuid
            current_seed_is_uuid = true
          else
            current_seed = File.join(cut_path, "frames", "%04d.png" % global_frame)
            current_seed_is_uuid = false
          end

          yield global_frame, script.total_frames
        end
      end
    end

    def render_single(cut_path : String, cut_id : Int64, script : MotionScript, frame_number : Int32)
      reference_path = File.join(cut_path, "reference.png")

      seed_image = if frame_number == 1
                     reference_path
                   else
                     File.join(cut_path, "frames", "%04d.png" % (frame_number - 1))
                   end

      raise "Seed image not found: #{seed_image}" unless File.exists?(seed_image)

      current = 0
      frame_spec : FrameSpec? = nil
      scene_name = ""

      script.scenes.each do |scene|
        next unless frames = scene.frames
        frames.each do |fs|
          current += 1
          if current == frame_number
            frame_spec = fs
            scene_name = scene.name
          end
        end
      end

      raise "Frame #{frame_number} not found in script" unless frame_spec

      fs = frame_spec.not_nil!
      request = GenerationRequest.new(
        prompt: fs.prompt,
        seed_image: seed_image,
        seed_is_uuid: false,
        width: fs.width || script.settings.width,
        height: fs.height || script.settings.height,
        model: fs.model || script.settings.model,
        strength: fs.strength || script.settings.strength,
        steps: fs.steps || script.settings.steps,
        cfg_scale: fs.cfg_scale || script.settings.cfg_scale
      )

      start_time = Time.instant
      result = @generator.generate(request)
      elapsed_ms = (Time.instant - start_time).total_milliseconds.to_i64

      metadata = FrameMetadata.new(
        frame_number: frame_number,
        scene: scene_name,
        prompt: fs.prompt,
        seed_image: frame_number == 1 ? "reference" : "frame_%04d" % (frame_number - 1),
        model: fs.model || script.settings.model,
        strength: fs.strength || script.settings.strength,
        width: fs.width || script.settings.width,
        height: fs.height || script.settings.height,
        task_uuid: result.response_id || "",
        generated_at: Time.utc,
        generation_time_ms: elapsed_ms,
        api_response_id: result.response_id
      )

      @store.save_frame(cut_path, cut_id, frame_number, result.image_data, metadata)
    end
  end
end
