module MJ
  # Cyclorama — extend an image believably to one side, and (by repeating) roll a
  # scene out into a much larger panorama. One "turn" = ask Nano Banana to draw the
  # image immediately adjacent to the current edge, matched to it, then butt-join it on.
  #
  # We always reason in a canonical "extend to the RIGHT" frame; a left extension is
  # done by mirroring the input, extending right, and mirroring the tile back — so the
  # prompt and marrying logic never branch.
  module Cyclorama
    extend self

    # The lean, human-style instruction that actually worked in testing: give the model
    # the reference and ask for the ADJACENT scene, not a widened copy (see the
    # boardwalk-panorama experiments — a verbose "orthographic/no-VP" wall made it worse).
    BASE_PROMPT =
      "Here is a reference image of a scene. Draw a NEW image of what lies immediately to " \
      "the RIGHT of it — a natural continuation of the very same scene. The LEFT edge of your " \
      "new image must line up with the RIGHT edge of the reference: keep the horizon and any " \
      "lines that run across the frame at the same heights and continue them without a break. " \
      "Match the exact same art style, colours, palette and lighting. Do NOT redraw the " \
      "reference — show what comes NEXT to the right of it. No text, no lettering, no people."

    def build_prompt(spec : CycloramaSpec) : String
      extra = spec.prompt.strip
      extra.empty? ? BASE_PROMPT : "#{BASE_PROMPT} #{extra}"
    end

    # Generate the next tile adjacent to `current` on the spec's side.
    # Returns a tile the same height as `current`, `spec.tile_width` wide.
    def extend(client : RunwareClient, current : StumpyPNG::Canvas, spec : CycloramaSpec) : StumpyPNG::Canvas
      left = spec.direction == "left"
      src = left ? flip_h(current) : current       # canonical: always extend rightward
      w = src.width
      h = src.height

      # Reference the leading (right, in canonical frame) edge window, not the whole
      # growing world — a bounded slice keeps the reference at full detail every step.
      win = (spec.context > 0 ? spec.context : spec.tile_width).clamp(1, w)
      ref = win >= w ? src : CanvasUtil.crop(src, w - win, 0, win, h)

      # Nano only outputs fixed sizes: request the nearest to the tile aspect, resize back.
      rw, rh = MJ.nano_dimensions(spec.tile_width, h)
      res = client.edit_references([CanvasUtil.to_png_bytes(ref)], build_prompt(spec), rw, rh, spec.model)
      tile = CanvasUtil.resize(CanvasUtil.from_png_bytes(res.image_data), spec.tile_width, h)
      left ? flip_h(tile) : tile
    end

    # Butt-join `tile` onto `current` on the correct side; returns the grown image.
    def join(current : StumpyPNG::Canvas, tile : StumpyPNG::Canvas, spec : CycloramaSpec) : StumpyPNG::Canvas
      parts = spec.direction == "left" ? [tile, current] : [current, tile]
      CanvasUtil.hconcat(parts)
    end

    # Mirror a canvas left<->right.
    private def flip_h(c : StumpyPNG::Canvas) : StumpyPNG::Canvas
      out = StumpyPNG::Canvas.new(c.width, c.height)
      (0...c.height).each do |y|
        (0...c.width).each do |x|
          out[c.width - 1 - x, y] = c[x, y]
        end
      end
      out
    end
  end
end
