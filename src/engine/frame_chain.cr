module Minanime
  class FrameChain
    def initialize(@generator : Generator, @store : FrameStore)
    end

    def render(cut_path : String, cut_id : Int64, script : MotionScript, &block : Int32, Int32 ->)
      reference_path = File.join(cut_path, "reference.png")
      raise "Reference image not found: #{reference_path}" unless File.exists?(reference_path)

      current_seed_path = reference_path
      frame_number = 0

      script.scenes.each do |scene|
        scene.frames.each do |frame_spec|
          frame_number += 1

          request = GenerationRequest.new(
            prompt: frame_spec.prompt,
            seed_image_path: current_seed_path,
            width: frame_spec.width || script.settings.width,
            height: frame_spec.height || script.settings.height,
            model: frame_spec.model || script.settings.model,
            strength: frame_spec.strength || script.settings.strength
          )

          start_time = Time.instant
          result = @generator.generate(request)
          elapsed_ms = (Time.instant - start_time).total_milliseconds.to_i64

          metadata = FrameMetadata.new(
            frame_number: frame_number,
            scene: scene.name,
            prompt: frame_spec.prompt,
            seed_image: current_seed_path == reference_path ? "reference" : "frame_%04d" % (frame_number - 1),
            model: frame_spec.model || script.settings.model,
            strength: frame_spec.strength || script.settings.strength,
            width: frame_spec.width || script.settings.width,
            height: frame_spec.height || script.settings.height,
            task_uuid: result.response_id || "",
            generated_at: Time.utc,
            generation_time_ms: elapsed_ms,
            api_response_id: result.response_id
          )

          stored_path = @store.save_frame(cut_path, cut_id, frame_number, result.image_data, metadata)
          current_seed_path = stored_path

          yield frame_number, script.total_frames
        end
      end
    end

    def render_single(cut_path : String, cut_id : Int64, script : MotionScript, frame_number : Int32)
      reference_path = File.join(cut_path, "reference.png")

      seed_path = if frame_number == 1
                    reference_path
                  else
                    File.join(cut_path, "frames", "%04d.png" % (frame_number - 1))
                  end

      raise "Seed image not found: #{seed_path}" unless File.exists?(seed_path)

      current = 0
      frame_spec : FrameSpec? = nil
      scene_name = ""

      script.scenes.each do |scene|
        scene.frames.each do |fs|
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
        seed_image_path: seed_path,
        width: fs.width || script.settings.width,
        height: fs.height || script.settings.height,
        model: fs.model || script.settings.model,
        strength: fs.strength || script.settings.strength
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
