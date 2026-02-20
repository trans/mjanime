module Minanime
  class ScriptSettings
    include YAML::Serializable

    property width : Int32 = 1024
    property height : Int32 = 1024
    property model : String = "runware:106@1"
    property strength : Float64 = 0.85

    def initialize(@width = 1024, @height = 1024, @model = "runware:106@1", @strength = 0.85)
    end
  end

  class FrameSpec
    include YAML::Serializable

    property prompt : String
    property strength : Float64?
    property model : String?
    property width : Int32?
    property height : Int32?
  end

  class Scene
    include YAML::Serializable

    property name : String
    property frames : Array(FrameSpec)
  end

  class MotionScript
    include YAML::Serializable

    property version : Int32 = 1
    property title : String
    property description : String = ""
    property settings : ScriptSettings = ScriptSettings.new
    property scenes : Array(Scene)

    def total_frames : Int32
      scenes.sum(&.frames.size)
    end
  end
end
