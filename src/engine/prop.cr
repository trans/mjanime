require "stumpy_png"

module Minanime
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
      bg_r = spec.background[0]
      bg_g = spec.background[1]
      bg_b = spec.background[2]
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

      out = StumpyPNG::Canvas.new(w, h)
      (0...h).each do |y|
        (0...w).each do |x|
          px = render[x, y]
          a = (alpha[y][x] * 65535.0).clamp(0.0, 65535.0).to_u16
          out[x, y] = StumpyPNG::RGBA.new(px.r, px.g, px.b, a)
        end
      end
      out
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
