module MJ
  class FrameMetadata
    include JSON::Serializable

    property frame_number : Int32
    property scene : String
    property prompt : String
    property seed_image : String
    property model : String
    property strength : Float64
    property width : Int32
    property height : Int32
    property task_uuid : String
    property api_response_id : String?
    property generated_at : Time
    property generation_time_ms : Int64

    def initialize(
      @frame_number, @scene, @prompt, @seed_image,
      @model, @strength, @width, @height,
      @task_uuid, @generated_at, @generation_time_ms,
      @api_response_id = nil
    )
    end
  end
end
