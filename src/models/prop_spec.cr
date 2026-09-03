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
    # Alpha bleed ("solidify"): keying zeros the bg's alpha but leaves its COLOUR in the
    # RGB channels. Non-premultiplied downscalers (thumbnailers, GPU mipmaps) blend that
    # hidden colour back in, so the key hue "reappears" as a fringe when the prop is shrunk.
    # This floods transparent pixels with the nearest subject colour (alpha stays 0) so
    # there's nothing left to resurrect. Default true; harmless in alpha-correct rendering.
    # Zero the alpha of the outermost N px of the frame (0 = off). The generated
    # background is not flat (see below), and its artefacts collect at the very edge as
    # strips that are 1-2px TALL but hundreds of px WIDE — so their area is far above any
    # sane `despeckle` threshold and despeckle cannot touch them. Those strips are what
    # defeats "crop to content": the bounding box is stuck at the full frame.
    # Safe by default because every prop is prompted to leave a margin — nothing should be
    # at the frame edge to lose. Set 0 for anything that deliberately bleeds off the edge.
    property edge_guard : Int32 = 2
    # Drop stray opaque islands smaller than this many pixels (0 = off). The generated
    # background is NOT flat: it carries a structured, block-patterned perturbation, so
    # pixels straddle the alpha ramp inconsistently and leave specks and edge crumbs.
    # OFF by default because legitimate thin detail IS small — frond tips, rope ends,
    # individual bulbs. Safe on solid-edged subjects (tents, buildings, machinery);
    # on feathery ones it eats the subject. See docs/techniques.md#despeckle.
    property despeckle : Int32 = 0
    property alpha_bleed : Bool = true
    property model : String = "google:4@3"   # Nano Banana 2 (google:4@1 is deprecated/weak)
    property width : Int32 = 1024
    property height : Int32 = 1024
    # Free-form tags for the prop library manifest (index.json). Seeds the tag-based
    # metadata a future TransFS/DataDungeon backend will index on. e.g. ["pirate", "metal"].
    # Repair the contaminated RIM: the band of pixels just inside the silhouette that came out of
    # the key still wearing backdrop colour. `despill` fixes anti-aliased edge pixels by unmatting,
    # but the rim is usually FULLY OPAQUE and so never qualifies — measured on a chroma-green cherry
    # blossom, that rim sat 28 levels DARKER than the interior and read as a hard olive outline the
    # moment the prop was composited over anything pale. Value is the rim width in px; 3 is a good
    # start.
    #
    # Off by default only because it changes every existing recipe on rekey — not because it is
    # risky. Measured across five props on two different key colours, `rim_bleed: 2` improved all
    # of them and over-reached on none (the third ring never moved).
    #
    # Judge it by HUE, not brightness. Compare the outer one or two pixel rings against the deep
    # interior: if the rings sit shifted toward the KEY colour, they are contaminated and this
    # fixes them. A first pass here used mean rim BRIGHTNESS and drew the wrong conclusion twice —
    # brightness legitimately rises at a sunlit silhouette edge (a shrub's outer leaves measured
    # +36 over its shaded interior with no contamination at all), and on a prop of two materials
    # a whole-rim average just mixes them into noise.
    property rim_bleed : Int32 = 0

    # Where this prop's GROUND LINE sits, as a fraction of the keyed content's height measured
    # UP from its bottom edge. 0.0 (the default) means the art meets the ground at its lowest
    # opaque pixel — right for a headstone, wrong for anything drawn with a spreading base. A
    # tree with an exposed root flare meets the soil part-way up its own silhouette; seating its
    # lowest root tip on the floor hangs the trunk in the air. Belongs to the PROP, not to a
    # scene, so every composition that places it gets the seating right for free.
    property ground_line : Float64 = 0.0

    property tags : Array(String) = [] of String
  end
end
