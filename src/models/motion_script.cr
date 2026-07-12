module MJ
  class ScriptSettings
    include YAML::Serializable

    property width : Int32 = 512
    property height : Int32 = 512
    property model : String = "civitai:4384@128713"
    property strength : Float64 = 0.6
    property steps : Int32 = 30
    property cfg_scale : Float64 = 3.5
    property controlnet_model : String? = nil
    property controlnet_weight : Float64 = 0.7
    property interpolation : String = "linear"

    def initialize(@width = 512, @height = 512, @model = "civitai:4384@128713",
                   @strength = 0.6, @steps = 30, @cfg_scale = 3.5,
                   @controlnet_model = nil, @controlnet_weight = 0.7,
                   @interpolation = "linear")
    end
  end

  class FrameSpec
    include YAML::Serializable

    property prompt : String
    property strength : Float64?
    property model : String?
    property width : Int32?
    property height : Int32?
    property steps : Int32?
    property cfg_scale : Float64?
  end

  # A keyframe defines joint positions at a specific frame number
  class KeyframeSpec
    include YAML::Serializable

    property frame : Int32
    property prompt : String?
    property joints : Hash(String, Array(Float64))? = nil
    property strength : Float64?
  end

  class Scene
    include YAML::Serializable

    property name : String
    # Legacy: direct frame list (prompt-based)
    property frames : Array(FrameSpec)? = nil
    # New: keyframe-based with interpolation
    property keyframes : Array(KeyframeSpec)? = nil
    property total_frames : Int32? = nil
  end

  class MotionScript
    include YAML::Serializable

    property version : Int32 = 1
    property title : String
    property description : String = ""
    property settings : ScriptSettings = ScriptSettings.new
    property scenes : Array(Scene)

    def total_frames : Int32
      scenes.sum do |scene|
        if tf = scene.total_frames
          tf
        elsif kfs = scene.keyframes
          kfs.empty? ? 0 : kfs.last.frame
        elsif fs = scene.frames
          fs.size
        else
          0
        end
      end
    end

    # Does this script use pose-based keyframes?
    def uses_poses? : Bool
      scenes.any? { |s| s.keyframes && !s.keyframes.try(&.empty?) }
    end
  end
end
