module Minanime
  struct GenerationResult
    getter image_data : Bytes
    getter response_id : String?

    def initialize(@image_data, @response_id = nil)
    end
  end

  struct GenerationRequest
    getter prompt : String
    getter seed_image_path : String
    getter width : Int32
    getter height : Int32
    getter model : String
    getter strength : Float64

    def initialize(@prompt, @seed_image_path, @width = 1024, @height = 1024,
                   @model = "runware:106@1", @strength = 0.85)
    end
  end

  module Generator
    abstract def generate(request : GenerationRequest) : GenerationResult
    abstract def name : String
  end
end
