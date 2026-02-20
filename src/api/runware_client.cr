require "http/client"
require "base64"
require "uuid"

module Minanime
  class RunwareClient
    include Generator

    def initialize(@api_key : String)
    end

    def name : String
      "runware"
    end

    def generate(request : GenerationRequest) : GenerationResult
      task_uuid = UUID.random.to_s

      seed_image_value = if request.seed_is_uuid
                           request.seed_image
                         else
                           image_bytes = File.read(request.seed_image).to_slice
                           base64 = Base64.strict_encode(image_bytes)
                           "data:image/png;base64,#{base64}"
                         end

      body = [{
        taskType:       "imageInference",
        taskUUID:       task_uuid,
        model:          request.model,
        positivePrompt: request.prompt,
        seedImage:      seed_image_value,
        strength:       request.strength,
        width:          request.width,
        height:         request.height,
        steps:          request.steps,
      }].to_json

      headers = HTTP::Headers{
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type"  => "application/json",
      }

      response = HTTP::Client.post(
        "https://api.runware.ai/v1",
        headers: headers,
        body: body
      )

      unless response.status_code == 200
        raise "Runware API error (#{response.status_code}): #{response.body}"
      end

      result = JSON.parse(response.body)
      data = result["data"].as_a
      task_result = data.find { |r| r["taskUUID"].as_s == task_uuid }
      raise "No result for task #{task_uuid}" unless task_result

      image_uuid = task_result["imageUUID"]?.try(&.as_s)

      image_url = task_result["imageURL"].as_s
      image_response = HTTP::Client.get(image_url)

      unless image_response.status_code == 200
        raise "Failed to download image from #{image_url}: #{image_response.status_code}"
      end

      GenerationResult.new(
        image_data: image_response.body.to_slice,
        response_id: task_uuid,
        image_uuid: image_uuid
      )
    end
  end
end
