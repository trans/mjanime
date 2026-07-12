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
  end
end
