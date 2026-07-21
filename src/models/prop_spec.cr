module MJ
  # Config for a transparent-background prop. Lives as `prop.yml` beside a `template.png`
  # (a rough flat-colour sketch: subject silhouette + feature colour patches). The template
  # is a *rough reference* for subject + size/placement, NOT a strict boundary — the model
  # paints outside the lines, and the result is cut out of the render (not the template).
  class PropSpec
    include YAML::Serializable

    property prompt : String
    # Background colour to render on. Name it in your prompt too. Default black (best for
    # bright subjects); use a contrasting colour (e.g. white [255,255,255] or chroma green
    # [0,255,0] / magenta [255,0,255]) when the subject itself is dark.
    property background : Array(Int32) = [0, 0, 0]
    # Key out the ACTUAL rendered corner colour instead of `background`. The model rarely
    # paints the exact colour you asked for (e.g. it lit a #FF00FF request as ~[194,68,168]),
    # so sampling the real corner is what makes chroma backgrounds key cleanly. Default true.
    property auto_background : Bool = true
    # Alpha ramp on distance-from-background (0..255, per-channel max): below key_low = fully
    # transparent, above key_high = fully opaque, smooth between. Lower key_high keeps faint
    # thin details (leaves, ropes); raise it for a cleaner cut (or to absorb a lit/gradient bg).
    property key_low : Int32 = 4
    property key_high : Int32 = 28
    # Soften the alpha edge by this many px (box blur on the alpha channel only). 0 = off.
    property edge_blur : Int32 = 0
    # Colour-unmatte edge pixels: recover the true foreground F = (C-(1-a)*B)/a so the
    # background tint is stripped out of anti-aliased edges. Kills chroma fringe on thin
    # detail (rigging, leaves). Default true; only touches partially-transparent pixels.
    property despill : Bool = true
    # Final defringe pass: subtract residual background-chroma cast (e.g. magenta/green
    # halo) that survives keying on very thin detail. Self-limiting — greys out the chroma
    # tint but leaves warm/neutral subject colour alone. Default true.
    property defringe : Bool = true
    # Restrict defringe to within this many px of a transparent pixel (the edge shell).
    # 0 = whole image (fine by default — the excess test is self-limiting). Set a small
    # band (1-3) only when the SUBJECT itself legitimately contains the key hue, so the
    # interior is left untouched. Requires defringe: true.
    property defringe_band : Int32 = 0
    property model : String = "google:4@3"   # Nano Banana 2 (google:4@1 is deprecated/weak)
    property width : Int32 = 1024
    property height : Int32 = 1024
  end
end
