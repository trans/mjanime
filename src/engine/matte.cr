require "stumpy_png"

module MJ
  # Background matting for arbitrary images.
  #
  # TIER 1 (procedural, this file): read the background colour from the image BORDERS, then flood-fill
  # inward to remove only the *connected* background — so a subject that happens to share the bg colour
  # is kept (unlike a global colour key). The flood grows along smooth colour steps (gradients,
  # vignettes) but is capped near the seed colour so it can't run into the subject. Then the edge is
  # softened, despilled (bg tint removed from the rim) and alpha-bled (so it survives downscaling).
  #
  # Best on simple / near-uniform backgrounds. Complex photos are Tier 2 (local rembg) / Tier 3
  # (Runware) — this module is the free, instant first pass.
  module Matte
    record Result, matte : StumpyPNG::Canvas, bg : Array(Int32), removed : Float64

    # local_tol: how large a per-step colour change still counts as background (follows gradients).
    # global_tol: hard cap on distance from the seed colour (stops the flood entering the subject).
    def self.remove_bg(src : StumpyPNG::Canvas, local_tol : Float64 = 20.0,
                       global_tol : Float64 = 70.0, feather : Int32 = 2,
                       despill : Bool = true, bleed : Bool = true) : Result
      w = src.width
      h = src.height
      seed = border_seed(src)
      sr = seed[0]; sg = seed[1]; sb = seed[2]

      # Connected-background mask via multi-source BFS from the borders.
      is_bg = Array(Array(Bool)).new(h) { Array(Bool).new(w, false) }
      q = Deque({Int32, Int32}).new
      seed_px = ->(x : Int32, y : Int32) do
        px = src[x, y]
        d = dist((px.r // 257).to_i, (px.g // 257).to_i, (px.b // 257).to_i, sr, sg, sb)
        if d <= global_tol && !is_bg[y][x]
          is_bg[y][x] = true
          q << {x, y}
        end
      end
      (0...w).each { |x| seed_px.call(x, 0); seed_px.call(x, h - 1) }
      (0...h).each { |y| seed_px.call(0, y); seed_px.call(w - 1, y) }

      while coord = q.shift?
        x, y = coord
        cp = src[x, y]
        pr = (cp.r // 257).to_i; pg = (cp.g // 257).to_i; pb = (cp.b // 257).to_i
        {% for d in [{-1, 0}, {1, 0}, {0, -1}, {0, 1}] %}
          nx = x + {{d[0]}}; ny = y + {{d[1]}}
          if nx >= 0 && ny >= 0 && nx < w && ny < h && !is_bg[ny][nx]
            np = src[nx, ny]
            nr = (np.r // 257).to_i; ng = (np.g // 257).to_i; nb = (np.b // 257).to_i
            if dist(nr, ng, nb, pr, pg, pb) <= local_tol && dist(nr, ng, nb, sr, sg, sb) <= global_tol
              is_bg[ny][nx] = true
              q << {nx, ny}
            end
          end
        {% end %}
      end

      # Contract the subject by `feather` (grow the bg inward) BEFORE softening, so the feathered
      # edge falls inside the subject rather than leaving a ring of background — kills the edge halo.
      is_bg = dilate(is_bg, w, h, feather) if feather > 0
      alpha = Array(Array(Float64)).new(h) { |y| Array(Float64).new(w) { |x| is_bg[y][x] ? 0.0 : 1.0 } }
      alpha = box_blur(alpha, w, h, feather) if feather > 0

      removed = 0_i64
      dst = StumpyPNG::Canvas.new(w, h)
      (0...h).each do |y|
        (0...w).each do |x|
          px = src[x, y]
          af = alpha[y][x]
          removed += 1 if af < 0.5
          a = (af * 65535.0).clamp(0.0, 65535.0).to_u16
          if despill && af > 0.02 && af < 0.999
            r = unmatte((px.r // 257).to_i, sr, af)
            g = unmatte((px.g // 257).to_i, sg, af)
            b = unmatte((px.b // 257).to_i, sb, af)
            dst[x, y] = StumpyPNG::RGBA.new((r * 257).to_u16, (g * 257).to_u16, (b * 257).to_u16, a)
          else
            dst[x, y] = StumpyPNG::RGBA.new(px.r, px.g, px.b, a)
          end
        end
      end
      bleed_alpha!(dst) if bleed
      Result.new(dst, seed, removed.to_f / (w * h))
    end

    ISNET_SIZE = 1024

    # Tier 2: local neural matting via IS-Net through the ONNX Runtime shim. Resize to the model's
    # 1024² input, normalise IS-Net style (x/255 − 0.5), run, min-max the score map, then bilinearly
    # upsample it back to the original size as the alpha channel and alpha-bleed. Handles arbitrary /
    # complex backgrounds a colour key can't. Requires onnxruntime-cpu + the .onnx model file.
    def self.isnet(src : StumpyPNG::Canvas, model_path : String, bleed : Bool = true) : StumpyPNG::Canvas
      w = src.width
      h = src.height
      small = CanvasUtil.resize(src, ISNET_SIZE, ISNET_SIZE)
      plane = ISNET_SIZE * ISNET_SIZE
      input = Slice(Float32).new(3 * plane)
      (0...ISNET_SIZE).each do |y|
        (0...ISNET_SIZE).each do |x|
          px = small[x, y]
          i = y * ISNET_SIZE + x
          input[i] = (px.r // 257) / 255.0_f32 - 0.5_f32
          input[plane + i] = (px.g // 257) / 255.0_f32 - 0.5_f32
          input[2 * plane + i] = (px.b // 257) / 255.0_f32 - 0.5_f32
        end
      end

      mask, oh, ow = Onnx.matte(model_path, input, ISNET_SIZE, ISNET_SIZE)

      # min-max normalise the raw score map to 0..1 (IS-Net outputs unbounded scores)
      mn = mask[0]
      mx = mask[0]
      mask.each do |v|
        mn = v if v < mn
        mx = v if v > mx
      end
      rng = (mx - mn) < 1e-6_f32 ? 1.0_f32 : (mx - mn)

      dst = StumpyPNG::Canvas.new(w, h)
      (0...h).each do |y|
        sy = ((y + 0.5) * oh / h - 0.5).clamp(0.0, (oh - 1).to_f)
        y0 = sy.to_i
        y1 = Math.min(y0 + 1, oh - 1)
        wy = (sy - y0).to_f32
        (0...w).each do |x|
          sx = ((x + 0.5) * ow / w - 0.5).clamp(0.0, (ow - 1).to_f)
          x0 = sx.to_i
          x1 = Math.min(x0 + 1, ow - 1)
          wx = (sx - x0).to_f32
          m00 = mask[y0 * ow + x0]
          m10 = mask[y0 * ow + x1]
          m01 = mask[y1 * ow + x0]
          m11 = mask[y1 * ow + x1]
          top = m00 + (m10 - m00) * wx
          bot = m01 + (m11 - m01) * wx
          v = (top + (bot - top) * wy - mn) / rng
          a = (v.clamp(0.0_f32, 1.0_f32) * 65535.0_f32).to_u16
          px = src[x, y]
          dst[x, y] = StumpyPNG::RGBA.new(px.r, px.g, px.b, a)
        end
      end
      bleed_alpha!(dst) if bleed
      dst
    end

    # Median border colour (per channel), robust to a subject touching an edge.
    private def self.border_seed(src : StumpyPNG::Canvas) : Array(Int32)
      w = src.width; h = src.height
      rs = [] of Int32; gs = [] of Int32; bs = [] of Int32
      ring = Math.max(1, Math.min(w, h) // 200)
      sample = ->(x : Int32, y : Int32) do
        px = src[x, y]; rs << (px.r // 257).to_i; gs << (px.g // 257).to_i; bs << (px.b // 257).to_i
      end
      (0...w).each { |x| (0...ring).each { |k| sample.call(x, k); sample.call(x, h - 1 - k) } }
      (0...h).each { |y| (0...ring).each { |k| sample.call(k, y); sample.call(w - 1 - k, y) } }
      [median(rs), median(gs), median(bs)]
    end

    private def self.median(a : Array(Int32)) : Int32
      return 0 if a.empty?
      a.sort![a.size // 2]
    end

    private def self.dist(r1, g1, b1, r2, g2, b2) : Float64
      {(r1 - r2).abs, (g1 - g2).abs, (b1 - b2).abs}.max.to_f
    end

    # Grow the true (background) mask by `iters` px via 4-neighbour dilation — contracts the subject.
    private def self.dilate(mask : Array(Array(Bool)), w : Int32, h : Int32, iters : Int32) : Array(Array(Bool))
      iters.times do
        nb = Array(Array(Bool)).new(h) { |y| mask[y].dup }
        (0...h).each do |y|
          (0...w).each do |x|
            next if mask[y][x]
            if (y > 0 && mask[y - 1][x]) || (y < h - 1 && mask[y + 1][x]) ||
               (x > 0 && mask[y][x - 1]) || (x < w - 1 && mask[y][x + 1])
              nb[y][x] = true
            end
          end
        end
        mask = nb
      end
      mask
    end

    private def self.unmatte(c : Int32, bg : Int32, a : Float64) : Int32
      ((c - (1.0 - a) * bg) / a).clamp(0.0, 255.0).to_i
    end

    # Flood transparent pixels with nearest subject colour (keeps alpha 0) so non-premultiplied
    # downscalers can't pull the removed background back in. Same idea as the prop keyer's bleed.
    private def self.bleed_alpha!(canvas : StumpyPNG::Canvas) : Nil
      w = canvas.width; h = canvas.height
      filled = Array(Array(Bool)).new(h) { Array(Bool).new(w, false) }
      q = Deque({Int32, Int32}).new
      (0...h).each { |y| (0...w).each { |x| (filled[y][x] = true; q << {x, y}) if canvas[x, y].a > 0 } }
      return if q.empty?
      while coord = q.shift?
        x, y = coord
        s = canvas[x, y]
        {% for d in [{-1, 0}, {1, 0}, {0, -1}, {0, 1}] %}
          nx = x + {{d[0]}}; ny = y + {{d[1]}}
          if nx >= 0 && ny >= 0 && nx < w && ny < h && !filled[ny][nx]
            filled[ny][nx] = true
            canvas[nx, ny] = StumpyPNG::RGBA.new(s.r, s.g, s.b, 0_u16)
            q << {nx, ny}
          end
        {% end %}
      end
    end

    private def self.box_blur(grid : Array(Array(Float64)), w : Int32, h : Int32, radius : Int32) : Array(Array(Float64))
      return grid if radius <= 0
      tmp = Array(Array(Float64)).new(h) { Array(Float64).new(w, 0.0) }
      (0...h).each do |y|
        (0...w).each do |x|
          sum = 0.0; n = 0
          (-radius..radius).each { |dx| xx = x + dx; (sum += grid[y][xx]; n += 1) if xx >= 0 && xx < w }
          tmp[y][x] = sum / n
        end
      end
      res = Array(Array(Float64)).new(h) { Array(Float64).new(w, 0.0) }
      (0...h).each do |y|
        (0...w).each do |x|
          sum = 0.0; n = 0
          (-radius..radius).each { |dy| yy = y + dy; (sum += tmp[yy][x]; n += 1) if yy >= 0 && yy < h }
          res[y][x] = sum / n
        end
      end
      res
    end
  end
end
