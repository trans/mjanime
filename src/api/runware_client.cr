require "http/client"
require "base64"
require "uuid"

module MJ
  class RunwareClient
    include Generator

    def initialize(@api_key : String)
    end

    def name : String
      "runware"
    end

    # Upload an image file and get back a UUID
    def upload_image(file_path : String) : String
      task_uuid = UUID.random.to_s

      image_bytes = File.read(file_path).to_slice
      base64 = Base64.strict_encode(image_bytes)
      data_uri = "data:image/png;base64,#{base64}"

      body = [{
        taskType: "imageUpload",
        taskUUID: task_uuid,
        image:    data_uri,
      }].to_json

      response = HTTP::Client.post(
        "https://api.runware.ai/v1",
        headers: auth_headers,
        body: body
      )

      unless response.status_code == 200
        raise "Runware upload error (#{response.status_code}): #{response.body}"
      end

      result = JSON.parse(response.body)
      data = result["data"].as_a
      task_result = data.find { |r| r["taskUUID"].as_s == task_uuid }
      raise "No upload result for task #{task_uuid}" unless task_result

      task_result["imageUUID"].as_s
    end

    # Upload raw PNG bytes and get back a UUID
    def upload_image_bytes(image_data : Bytes) : String
      task_uuid = UUID.random.to_s

      base64 = Base64.strict_encode(image_data)
      data_uri = "data:image/png;base64,#{base64}"

      body = [{
        taskType: "imageUpload",
        taskUUID: task_uuid,
        image:    data_uri,
      }].to_json

      response = HTTP::Client.post(
        "https://api.runware.ai/v1",
        headers: auth_headers,
        body: body
      )

      unless response.status_code == 200
        raise "Runware upload error (#{response.status_code}): #{response.body}"
      end

      result = JSON.parse(response.body)
      data = result["data"].as_a
      task_result = data.find { |r| r["taskUUID"].as_s == task_uuid }
      raise "No upload result for task #{task_uuid}" unless task_result

      task_result["imageUUID"].as_s
    end

    # Extract OpenPose skeleton from an image via ControlNet preprocessing
    def preprocess_pose(image_uuid : String, width : Int32, height : Int32) : {String, String}
      task_uuid = UUID.random.to_s

      body = [{
        taskType:         "imageControlNetPreProcess",
        taskUUID:         task_uuid,
        inputImage:       image_uuid,
        preProcessorType: "openpose",
        width:            width,
        height:           height,
        outputType:       "URL",
        outputFormat:     "PNG",
      }].to_json

      STDERR.puts "[runware] Preprocessing pose: image=#{image_uuid} #{width}x#{height}"

      response = HTTP::Client.post(
        "https://api.runware.ai/v1",
        headers: auth_headers,
        body: body
      )

      unless response.status_code == 200
        raise "Runware preprocess error (#{response.status_code}): #{response.body}"
      end

      result = JSON.parse(response.body)
      data = result["data"].as_a
      task_result = data.find { |r| r["taskUUID"].as_s == task_uuid }
      raise "No preprocess result for task #{task_uuid}" unless task_result

      guide_uuid = task_result["guideImageUUID"].as_s
      guide_url = task_result["guideImageURL"].as_s

      STDERR.puts "[runware] Pose extracted: guideUUID=#{guide_uuid}"
      {guide_uuid, guide_url}
    end

    def generate(request : GenerationRequest) : GenerationResult
      task_uuid = UUID.random.to_s

      # If it's a file path, upload first to get a UUID
      image_uuid = if request.seed_is_uuid
                     request.seed_image
                   else
                     STDERR.puts "[runware] Uploading seed image: #{request.seed_image} (#{File.size(request.seed_image)} bytes)"
                     uuid = upload_image(request.seed_image)
                     STDERR.puts "[runware] Upload returned UUID: #{uuid}"
                     uuid
                   end

      width, height = MJ.snap_dimensions(request.width, request.height, request.model)

      STDERR.puts "[runware] Generate: model=#{request.model} seed=#{image_uuid} strength=#{request.strength} #{width}x#{height} steps=#{request.steps}"
      STDERR.puts "[runware] Prompt: #{request.prompt}"

      # Build the base task
      task = JSON.build do |json|
        json.array do
          json.object do
            json.field "taskType", "imageInference"
            json.field "taskUUID", task_uuid
            json.field "model", request.model
            json.field "positivePrompt", request.prompt
            json.field "negativePrompt", request.negative_prompt unless request.negative_prompt.empty?
            json.field "seedImage", image_uuid
            json.field "strength", request.strength
            json.field "CFGScale", request.cfg_scale
            json.field "width", width
            json.field "height", height
            json.field "steps", request.steps
            json.field "outputType", "URL"
            json.field "outputFormat", "PNG"

            # Add ControlNet if present
            if cn = request.controlnet
              STDERR.puts "[runware] ControlNet: #{cn.size} config(s)"
              json.field "controlNet" do
                json.array do
                  cn.each do |param|
                    json.object do
                      json.field "model", param.model
                      json.field "guideImage", param.guide_image
                      json.field "weight", param.weight
                      json.field "startStep", param.start_step
                      json.field "endStep", param.end_step
                      json.field "controlMode", param.control_mode
                    end
                  end
                end
              end
            end
          end
        end
      end

      post_inference(task, task_uuid)
    end

    # Inpaint a region of a seed image. seed_bytes is the composite canvas,
    # mask_bytes is the black/white mask (white = regenerate). Both are uploaded
    # before the inference call. Used to invent transition terrain in strip gaps.
    def inpaint(seed_bytes : Bytes, mask_bytes : Bytes, prompt : String,
                width : Int32, height : Int32, model : String,
                steps : Int32 = 30, strength : Float64 = 1.0,
                cfg_scale : Float64 = 3.5, mask_margin : Int32? = nil,
                negative_prompt : String = "") : GenerationResult
      task_uuid = UUID.random.to_s

      STDERR.puts "[runware] Inpaint: model=#{model} #{width}x#{height} steps=#{steps}"
      seed_uuid = upload_image_bytes(seed_bytes)
      mask_uuid = upload_image_bytes(mask_bytes)

      body = JSON.build do |json|
        json.array do
          json.object do
            json.field "taskType", "imageInference"
            json.field "taskUUID", task_uuid
            json.field "model", model
            json.field "positivePrompt", prompt
            json.field "negativePrompt", negative_prompt unless negative_prompt.empty?
            json.field "seedImage", seed_uuid
            json.field "maskImage", mask_uuid
            json.field "width", width
            json.field "height", height
            json.field "steps", steps
            json.field "CFGScale", cfg_scale
            json.field "outputType", "URL"
            json.field "outputFormat", "PNG"
            # FLUX Fill (runware:102@1) ignores strength; omit it there.
            json.field "strength", strength unless model.starts_with?("runware:102@")
            if mm = mask_margin
              json.field "maskMargin", mm
            end
          end
        end
      end

      post_inference(body, task_uuid)
    end

    # Reference-image editing (Nano Banana / Gemini Flash Image, google:4@x).
    # positivePrompt is a natural-language instruction; the model regenerates
    # the whole output guided by the reference images and instruction (no mask).
    def edit_references(reference_bytes : Array(Bytes), prompt : String,
                        width : Int32, height : Int32, model : String) : GenerationResult
      task_uuid = UUID.random.to_s
      STDERR.puts "[runware] Edit(refs=#{reference_bytes.size}): model=#{model} #{width}x#{height}"
      ref_uuids = reference_bytes.map { |b| upload_image_bytes(b) }

      body = JSON.build do |json|
        json.array do
          json.object do
            json.field "taskType", "imageInference"
            json.field "taskUUID", task_uuid
            json.field "model", model
            json.field "positivePrompt", prompt
            json.field "width", width
            json.field "height", height
            json.field "outputType", "URL"
            json.field "outputFormat", "PNG"
            json.field "inputs" do
              json.object do
                json.field "referenceImages" do
                  json.array { ref_uuids.each { |u| json.string u } }
                end
              end
            end
          end
        end
      end

      post_inference(body, task_uuid)
    end

    # POST an imageInference task body, resolve its result, and download the image.
    private def post_inference(body : String, task_uuid : String) : GenerationResult
      response = HTTP::Client.post(
        "https://api.runware.ai/v1",
        headers: auth_headers,
        body: body
      )

      unless response.status_code == 200
        raise "Runware API error (#{response.status_code}): #{response.body}"
      end

      result = JSON.parse(response.body)
      data = result["data"].as_a
      task_result = data.find { |r| r["taskUUID"].as_s == task_uuid }
      raise "No result for task #{task_uuid}" unless task_result

      result_uuid = task_result["imageUUID"]?.try(&.as_s)
      STDERR.puts "[runware] Result: imageUUID=#{result_uuid}"

      image_url = task_result["imageURL"].as_s
      image_response = HTTP::Client.get(image_url)

      unless image_response.status_code == 200
        raise "Failed to download image from #{image_url}: #{image_response.status_code}"
      end

      GenerationResult.new(
        image_data: image_response.body.to_slice,
        response_id: task_uuid,
        image_uuid: result_uuid
      )
    end

    private def auth_headers : HTTP::Headers
      HTTP::Headers{
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type"  => "application/json",
      }
    end
  end
end
