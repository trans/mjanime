module MJ
  # Config for a Stage-2 "decorate" generation. Lives as `decorate.yml` beside an
  # `image.png` (the plain "bed" master from Stage 1, or any image to restyle).
  # Run:  mj decorate <dir>   -> writes decorated.png
  #
  # Takes the master as a reference and redraws it decorated in the given style/theme
  # (Nano Banana 2). An optional `style.png` beside the master is passed as a second
  # reference to steer the look. `keep_structure` prepends a silhouette-preserving lead
  # so the decoration honours the master's form instead of wandering off.
  class DecorateSpec
    include YAML::Serializable

    property prompt : String                 # the style / theme / details to apply
    property keep_structure : Bool = true    # preserve the master's silhouette/layout
    property model : String = "google:4@3"   # Nano Banana 2
    property width : Int32 = 1024
    property height : Int32 = 1024
  end
end
