module MJ
  # Config for a pixel-art restyle. Lives as `pixel.yml` beside an `image.png`.
  # Run:  mj pixelize <dir>   -> writes redraw.png (raw AI) + pixel.png (final).
  #
  # The look ("8-bit" vs "16-bit") is driven by `style`, which selects a prompt template —
  # Nano Banana 2 (google:4@3) infers pixel density and palette from the era name. `width`/
  # `height` set the CANVAS size, not the pixel granularity.
  #
  # `snap` and `background` are independent optional post-passes:
  #   - snap: downscale to a true `grid` + quantize to `colors` + nearest upscale, for
  #     pixel-perfect authenticity. Off by default — the raw AI redraw already reads as
  #     pixel art. Requires ImageMagick (`magick`) on PATH.
  #   - background: "transparent" keys out a flat magenta chroma field (prompted for and
  #     removed); "keep" leaves the AI's background; "#RRGGBB" requests a solid colour bg.
  class PixelSpec
    include YAML::Serializable

    property style : String = "16bit"          # 8bit | 16bit
    property prompt : String = ""              # optional extra instruction, appended
    property model : String = "google:4@3"     # Nano Banana 2; 4@2 (Pro) also works
    property width : Int32 = 1024
    property height : Int32 = 1024
    property snap : Bool = false               # deterministic pixel-perfect pass (needs ImageMagick)
    property grid : Int32 = 128                # snap: true pixel resolution (8bit~64, 16bit~128)
    property colors : Int32 = 32               # snap: palette size (8bit~16, 16bit~32, up to ~256)
    property background : String = "transparent" # transparent | keep | #RRGGBB
    # Transparent-background keying (only when background == "transparent"). Routed through the
    # PROP keyer so edges get despilled and transparent pixels solidified — otherwise a magenta
    # fringe outlines the sprite and resurrects when it's downscaled. Distance-from-magenta ramp
    # (per-channel max, 0..255): below key_low = transparent, above key_high = opaque.
    property key_low : Int32 = 40
    property key_high : Int32 = 110
    property despill : Bool = true             # recover true F = (C-(1-a)B)/a on edge pixels
    property defringe : Bool = true            # subtract residual magenta cast near edges
    # Restrict defringe to this many px of a transparent pixel. Default 2 (edge shell only) so
    # legitimately magenta/pink pop-art colours in the SUBJECT interior are left alone.
    property defringe_band : Int32 = 2
    property alpha_bleed : Bool = true         # flood transparent pixels with nearest subject colour
  end
end
