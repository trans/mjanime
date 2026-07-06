module Minanime
  struct ControlNetParam
    getter model : String
    getter guide_image : String  # UUID or data URI
    getter weight : Float64
    getter start_step : Int32
    getter end_step : Int32
    getter control_mode : String

    def initialize(@model, @guide_image, @weight = 0.7, @start_step = 0, @end_step = 30, @control_mode = "balanced")
    end

    def to_json_object
      {
        model:       @model,
        guideImage:  @guide_image,
        weight:      @weight,
        startStep:   @start_step,
        endStep:     @end_step,
        controlMode: @control_mode,
      }
    end
  end

  # Preset ControlNet configurations
  module ControlNetPresets
    # SD 1.5 OpenPose ControlNet v1.1
    SD15_OPENPOSE_MODEL = "civitai:38784@44811"

    # FLUX ControlNet Union Pro 2.0 (supports pose mode)
    FLUX_UNION_MODEL = "runware:110@1"

    def self.sd15_openpose(guide_image : String, weight = 0.7, steps = 30) : ControlNetParam
      ControlNetParam.new(
        model: SD15_OPENPOSE_MODEL,
        guide_image: guide_image,
        weight: weight,
        start_step: 0,
        end_step: steps,
        control_mode: "balanced"
      )
    end

    def self.flux_union_pose(guide_image : String, weight = 0.9, steps = 20) : ControlNetParam
      ControlNetParam.new(
        model: FLUX_UNION_MODEL,
        guide_image: guide_image,
        weight: weight,
        start_step: 0,
        end_step: (steps * 0.65).to_i,
        control_mode: "controlnet"
      )
    end
  end
end
