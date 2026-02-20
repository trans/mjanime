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

    def initialize(@prompt, @seed_image, @seed_is_uuid = false, @width = 1024, @height = 1024,
                   @model = "runware:106@1", @strength = 0.95, @steps = 25)
    end
  end

  module Generator
    abstract def generate(request : GenerationRequest) : GenerationResult
    abstract def name : String
  end
end
