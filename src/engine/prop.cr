require "stumpy_png"

module MJ
  # The "prop machine": a rough flat-colour template -> a 2D game prop with a
  # transparent background.
  #
  # Recipe (validated on barrel / plant / clown):
  #   1. Nano Banana (edit_references) paints the subject over a solid, known
  #      background colour. The template is a *rough* reference for subject +
  #      size/placement; the model paints outside the lines, so we cut the prop
  #      out of the RENDER, never the template.
  #   2. Key on distance-from-background: each pixel's alpha ramps from 0 (equal
  #      to the bg colour) to 1 (far from it). This generalises the old
  #      black->transparent trick to ANY background colour, so a dark/black
  #      subject can be rendered on a contrasting bg (white / chroma green) and
  #      still key cleanly.
  #   3. Optional box-blur on the alpha channel to soften the edge.
  #
  # No matting model, no strict silhouette fit — soft edges tolerate the drift.
  module Prop
    record Result, render : StumpyPNG::Canvas, prop : StumpyPNG::Canvas

    # Convenience: read the template from disk. Delegates to the in-memory form.
    def self.generate(client : RunwareClient, template_path : String, spec : PropSpec) : Result
      raise "Template not found: #{template_path}" unless File.exists?(template_path)
      generate(client, File.read(template_path).to_slice, spec)
    end

    # Fully in-memory: template PNG bytes in, {render, prop} canvases out. No disk I/O.
    def self.generate(client : RunwareClient, template_bytes : Bytes, spec : PropSpec) : Result
      res = client.edit_references([template_bytes], spec.prompt, spec.width, spec.height, spec.model)
      render = CanvasUtil.from_png_bytes(res.image_data)
      prop = key_out(render, spec)
      Result.new(render, prop)
    end

    # Build the transparent prop from a finished render by keying out the bg colour.
    def self.key_out(render : StumpyPNG::Canvas, spec : PropSpec) : StumpyPNG::Canvas
      w = render.width
      h = render.height
      # Key the ACTUAL rendered background (sampled from the corners), not the nominal one —
      # the model rarely paints the exact colour requested. Falls back to spec.background.
      bg = spec.auto_background ? sample_bg(render) : spec.background
      bg_r = bg[0]
      bg_g = bg[1]
      bg_b = bg[2]
      lo = spec.key_low.to_f
      hi = spec.key_high.to_f
      span = (hi - lo).abs < 1e-6 ? 1.0 : (hi - lo)

      # alpha as a Float64 grid so we can blur it before quantising.
      alpha = Array(Array(Float64)).new(h) { Array(Float64).new(w, 0.0) }
      (0...h).each do |y|
        (0...w).each do |x|
          px = render[x, y]
          dr = ((px.r // 257).to_i - bg_r).abs
          dg = ((px.g // 257).to_i - bg_g).abs
          db = ((px.b // 257).to_i - bg_b).abs
          dist = {dr, dg, db}.max.to_f
          t = ((dist - lo) / span).clamp(0.0, 1.0)
          alpha[y][x] = t * t * (3.0 - 2.0 * t) # smoothstep
        end
      end

      alpha = box_blur(alpha, w, h, spec.edge_blur) if spec.edge_blur > 0

      dst = StumpyPNG::Canvas.new(w, h)
      (0...h).each do |y|
        (0...w).each do |x|
          px = render[x, y]
          af = alpha[y][x]
          a = (af * 65535.0).clamp(0.0, 65535.0).to_u16
          if spec.despill && af > 0.02 && af < 0.999
            # Colour unmatting: the render is the foreground composited over the
            # known bg, C = a*F + (1-a)*B, so recover F = (C - (1-a)*B) / a. This
            # strips the bg tint out of every anti-aliased edge pixel — the fix for
            # chroma fringe on thin detail (rigging, leaves) where half the pixel
            # is background.
            r = unmatte((px.r // 257).to_i, bg_r, af)
            g = unmatte((px.g // 257).to_i, bg_g, af)
            b = unmatte((px.b // 257).to_i, bg_b, af)
            dst[x, y] = StumpyPNG::RGBA.new((r * 257).to_u16, (g * 257).to_u16, (b * 257).to_u16, a)
          else
            dst[x, y] = StumpyPNG::RGBA.new(px.r, px.g, px.b, a)
          end
        end
      end
      defringe!(dst, bg_r, bg_g, bg_b) if spec.defringe
      dst
    end

    # Recover one foreground channel from a pixel composited over the bg colour.
    private def self.unmatte(c : Int32, bg : Int32, a : Float64) : Int32
      ((c - (1.0 - a) * bg) / a).clamp(0.0, 255.0).to_i
    end

    # Kill residual background-chroma cast (magenta/green fringe) left on thin
    # detail after keying. The bg colour picks the chroma channels; we subtract
    # only the SHARED excess those channels carry over the neutral ("clean")
    # channel(s), so a magenta halo greys out while genuinely warm/neutral subject
    # pixels (where the chroma channels aren't jointly elevated) are left alone.
    # Self-limiting: does nothing to pixels that don't lean toward the bg hue.
    private def self.defringe!(canvas : StumpyPNG::Canvas, bg_r : Int32, bg_g : Int32, bg_b : Int32) : Nil
      bg = {bg_r, bg_g, bg_b}
      mean = (bg_r + bg_g + bg_b) / 3.0
      chroma = (0..2).select { |i| bg[i] > mean + 8 }
      return if chroma.empty? || chroma.size == 3 # neutral/near-neutral bg: nothing to strip
      clean = (0..2).to_a - chroma

      (0...canvas.height).each do |y|
        (0...canvas.width).each do |x|
          px = canvas[x, y]
          next if px.a == 0
          c = [(px.r // 257).to_i, (px.g // 257).to_i, (px.b // 257).to_i]
          ex = if chroma.size == 2
                 # magenta/cyan/yellow: excess is how far BOTH chroma channels sit above the clean one
                 base = c[clean[0]]
                 chroma.min_of { |i| c[i] - base }
               else
                 # red/green/blue: excess of the lone chroma channel over the brighter clean one
                 base = clean.max_of { |i| c[i] }
                 c[chroma[0]] - base
               end
          next if ex <= 0
          chroma.each { |i| c[i] -= ex }
          canvas[x, y] = StumpyPNG::RGBA.new(
            (c[0].clamp(0, 255) * 257).to_u16,
            (c[1].clamp(0, 255) * 257).to_u16,
            (c[2].clamp(0, 255) * 257).to_u16, px.a)
        end
      end
    end

    # Average the background colour from the four corners of the render (each a small square).
    private def self.sample_bg(render : StumpyPNG::Canvas) : Array(Int32)
      w = render.width
      h = render.height
      s = Math.max(2, Math.min(w, h) // 40)
      rs = 0_i64
      gs = 0_i64
      bs = 0_i64
      n = 0_i64
      [{0, 0}, {w - s, 0}, {0, h - s}, {w - s, h - s}].each do |cx, cy|
        (0...s).each do |dy|
          (0...s).each do |dx|
            px = render[cx + dx, cy + dy]
            rs += (px.r // 257)
            gs += (px.g // 257)
            bs += (px.b // 257)
            n += 1
          end
        end
      end
      [(rs // n).to_i, (gs // n).to_i, (bs // n).to_i]
    end

    # Separable box blur on a Float64 grid (used on the alpha channel only).
    private def self.box_blur(grid : Array(Array(Float64)), w : Int32, h : Int32, radius : Int32) : Array(Array(Float64))
      return grid if radius <= 0
      tmp = Array(Array(Float64)).new(h) { Array(Float64).new(w, 0.0) }
      (0...h).each do |y|
        (0...w).each do |x|
          sum = 0.0
          n = 0
          (-radius..radius).each do |dx|
            xx = x + dx
            next unless xx >= 0 && xx < w
            sum += grid[y][xx]
            n += 1
          end
          tmp[y][x] = sum / n
        end
      end
      out = Array(Array(Float64)).new(h) { Array(Float64).new(w, 0.0) }
      (0...h).each do |y|
        (0...w).each do |x|
          sum = 0.0
          n = 0
          (-radius..radius).each do |dy|
            yy = y + dy
            next unless yy >= 0 && yy < h
            sum += tmp[yy][x]
            n += 1
          end
          out[y][x] = sum / n
        end
      end
      out
    end
  end
end
