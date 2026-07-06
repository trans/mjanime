module Minanime
  # Config for a scenery-strip build. Lives as `strip.yml` inside a folder
  # of ordered source PNGs. The pipeline stylizes each source, then invents
  # transition terrain between neighbours to produce one long seamless image.
  class StripScript
    include YAML::Serializable

    property title : String = "scenery strip"

    # When true, skip stylization entirely: use the source images untouched and
    # only generate the gaps (bridges conditioned on the ORIGINAL edges).
    property passthrough : Bool = false

    # -- Stylization (applied to every source tile) --
    property style_prompt : String = ""
    property negative_prompt : String = ""
    property tile_model : String = "civitai:4384@128713"
    property tile_strength : Float64 = 0.55
    property tile_steps : Int32 = 30
    property tile_cfg_scale : Float64 = 3.5

    # Normalized tile height. nil => infer from the source images.
    property height : Int32? = nil
    # Fixed width for every stylized tile. nil => derive from each source's aspect.
    property tile_width : Int32? = nil

    # -- Gap bridging (invented transition terrain between tiles) --
    # Prompt for the invented terrain; falls back to style_prompt when nil.
    property bridge_prompt : String? = nil
    # FLUX Fill by default — purpose-built for inpaint/outpaint, ignores strength.
    property bridge_model : String = "runware:102@1"
    property gap_width : Int32 = 512      # width of invented terrain between two tiles
    property context_width : Int32 = 192  # px of each neighbour's edge fed in as context
    property feather : Int32 = 48         # gray ramp softening each seam
    property bridge_steps : Int32 = 30
    property bridge_strength : Float64 = 1.0

    # Explicit source order (filenames within the folder). nil => sorted *.png.
    property sources : Array(String)? = nil

    def bridge_prompt! : String
      bridge_prompt || style_prompt
    end
  end
end
