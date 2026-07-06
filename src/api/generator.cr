module Minanime
  struct GenerationResult
    getter image_data : Bytes
    getter response_id : String?
    getter image_uuid : String?

    def initialize(@image_data, @response_id = nil, @image_uuid = nil)
    end
  end

  struct GenerationRequest
    getter prompt : String
    getter seed_image : String  # Either a file path (for first frame) or a Runware UUID
    getter seed_is_uuid : Bool
    getter width : Int32
    getter height : Int32
    getter model : String
    getter strength : Float64
    getter steps : Int32
    getter cfg_scale : Float64
    getter controlnet : Array(ControlNetParam)?
    getter negative_prompt : String

    def initialize(@prompt, @seed_image, @seed_is_uuid = false, @width = 720, @height = 512,
                   @model = "civitai:4384@128713", @strength = 0.6, @steps = 30, @cfg_scale = 3.5,
                   @controlnet = nil, @negative_prompt = "")
    end
  end

  module Generator
    abstract def generate(request : GenerationRequest) : GenerationResult
    abstract def name : String
  end
end
