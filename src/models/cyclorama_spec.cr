module MJ
  # Config for `mj cyclorama` — extend an image believably to one side, and by
  # repeating that step roll out a much larger panorama / "world". Lives as
  # `cyclorama.yml` beside a seed image. Run:  mj cyclorama <dir> [--steps N]
  #   -> grows world.png; each new tile also saved under tiles/NNN.png.
  #
  # One "turn" = generate the scene immediately adjacent to the current edge,
  # married to it, via Nano Banana reference editing. The source seed image is
  # never modified (it is copied to world.png on the first run).
  class CycloramaSpec
    include YAML::Serializable

    # What to depict / how to continue. Appended to the base "draw what's next"
    # instruction. Leave empty to just continue the scene generically.
    property prompt : String = ""
    property model : String = "google:4@3"      # Nano Banana 2 (deterministic edit model)
    # Side to extend toward. "left" is handled by mirroring, so the prompt logic
    # stays identical.
    property direction : String = "right"        # right | left
    # Width (px) of each new extension tile; its height matches the current world.
    property tile_width : Int32 = 1024
    # Px of the leading edge shown to the model as the reference. 0 = one `tile_width`
    # window (recommended) — so the reference stays a bounded, recent slice instead of
    # the whole growing world (feeding the whole world squishes it smaller every step).
    # Increase for more context, or set larger than the world to feed the whole image.
    property context : Int32 = 0
    # Starting image filename inside the dir; copied to world.png on the first run.
    property seed : String = "seed.png"
  end
end
