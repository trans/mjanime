module MJ
  # Config for a Stage-1 "bed" generation. Lives as `bed.yml` beside a `template.png`
  # (a rudimentary flat-colour sketch: silhouette + door/window colour patches). The bed
  # is a plain, undecorated, structurally-faithful render used as the master reference for
  # later decorated variations.
  class BedSpec
    include YAML::Serializable

    property prompt : String
    # Legend text is just part of the prompt (e.g. "the dark-red patch is the doorway").
    property negative_prompt : String = "decoration, decorative, trim, stripes, pattern, bunting, " \
      "flags, garland, string lights, ornament, busy, cluttered, scenery, landscape, ground, people, text, watermark"
    property model : String = "civitai:4384@128713"   # SD1.5; FLUX img2img underperforms on flat masks
    property strength : Float64 = 0.7                  # plain<->rich structure knob (~0.7 rich but undecorated)
    property steps : Int32 = 30
    property cfg_scale : Float64 = 4.5
  end
end
