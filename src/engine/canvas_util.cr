require "stumpy_png"

module Minanime
  # Pure-Crystal image compositing helpers built on stumpy.
  # Used by the scenery-strip pipeline to crop tile edges, build inpaint
  # masks, and stitch tiles + generated bridges into one long image.
  module CanvasUtil
    BLACK = StumpyPNG::RGBA.new(0_u16, 0_u16, 0_u16, 65535_u16)
    WHITE = StumpyPNG::RGBA.new(65535_u16, 65535_u16, 65535_u16, 65535_u16)

    def self.from_png_bytes(bytes : Bytes) : StumpyPNG::Canvas
      StumpyPNG.read(IO::Memory.new(bytes))
    end

    def self.from_png_file(path : String) : StumpyPNG::Canvas
      StumpyPNG.read(path)
    end

    def self.to_png_bytes(canvas : StumpyPNG::Canvas) : Bytes
      io = IO::Memory.new
      StumpyPNG.write(canvas, io)
      io.to_slice.dup
    end

    def self.write_png_file(canvas : StumpyPNG::Canvas, path : String)
      StumpyPNG.write(canvas, path)
    end

    # Bilinear resize to exactly (w, h). Returns src unchanged if already that size.
    def self.resize(src : StumpyPNG::Canvas, w : Int32, h : Int32) : StumpyPNG::Canvas
      return src if src.width == w && src.height == h
      dst = StumpyPNG::Canvas.new(w, h, BLACK)
      sx_ratio = src.width / w.to_f
      sy_ratio = src.height / h.to_f
      (0...h).each do |dy|
        fy = (dy + 0.5) * sy_ratio - 0.5
        y0 = fy.floor.to_i.clamp(0, src.height - 1)
        y1 = (y0 + 1).clamp(0, src.height - 1)
        wy = (fy - y0).clamp(0.0, 1.0)
        (0...w).each do |dx|
          fx = (dx + 0.5) * sx_ratio - 0.5
          x0 = fx.floor.to_i.clamp(0, src.width - 1)
          x1 = (x0 + 1).clamp(0, src.width - 1)
          wx = (fx - x0).clamp(0.0, 1.0)
          c00 = src[x0, y0]; c10 = src[x1, y0]; c01 = src[x0, y1]; c11 = src[x1, y1]
          r = bilerp(c00.r, c10.r, c01.r, c11.r, wx, wy)
          g = bilerp(c00.g, c10.g, c01.g, c11.g, wx, wy)
          b = bilerp(c00.b, c10.b, c01.b, c11.b, wx, wy)
          dst[dx, dy] = StumpyPNG::RGBA.new(r, g, b, 65535_u16)
        end
      end
      dst
    end

    private def self.bilerp(c00 : UInt16, c10 : UInt16, c01 : UInt16, c11 : UInt16, wx : Float64, wy : Float64) : UInt16
      top = c00 + (c10.to_f - c00) * wx
      bot = c01 + (c11.to_f - c01) * wx
      (top + (bot - top) * wy).clamp(0.0, 65535.0).to_u16
    end

    # Copy a sub-rectangle out of a canvas.
    def self.crop(src : StumpyPNG::Canvas, x : Int32, y : Int32, w : Int32, h : Int32) : StumpyPNG::Canvas
      dst = StumpyPNG::Canvas.new(w, h, BLACK)
      (0...h).each do |dy|
        (0...w).each do |dx|
          sx = x + dx
          sy = y + dy
          next unless sx >= 0 && sx < src.width && sy >= 0 && sy < src.height
          dst[dx, dy] = src[sx, sy]
        end
      end
      dst
    end

    # Paste src onto dst with its top-left at (ox, oy).
    def self.paste(dst : StumpyPNG::Canvas, src : StumpyPNG::Canvas, ox : Int32, oy : Int32)
      (0...src.height).each do |sy|
        (0...src.width).each do |sx|
          dx = ox + sx
          dy = oy + sy
          next unless dx >= 0 && dx < dst.width && dy >= 0 && dy < dst.height
          dst[dx, dy] = src[sx, sy]
        end
      end
    end

    # Concatenate canvases left-to-right. Height is the max of the inputs;
    # shorter canvases are top-aligned on a black background.
    def self.hconcat(canvases : Array(StumpyPNG::Canvas)) : StumpyPNG::Canvas
      h = canvases.map(&.height).max
      total_w = canvases.sum(&.width)
      dst = StumpyPNG::Canvas.new(total_w, h, BLACK)
      x = 0
      canvases.each do |c|
        paste(dst, c, x, 0)
        x += c.width
      end
      dst
    end

    # Fill a gap [gx, gx+gw) in `dst` with a per-row linear blend between
    # `left`'s column `left_x` and `right`'s column `right_x`. Gives an inpaint
    # model coherent pixels to refine instead of an empty hole.
    def self.fill_hblend(dst : StumpyPNG::Canvas, left : StumpyPNG::Canvas, left_x : Int32,
                         right : StumpyPNG::Canvas, right_x : Int32, gx : Int32, gw : Int32, height : Int32)
      (0...height).each do |y|
        ca = left[left_x, y]
        cb = right[right_x, y]
        (0...gw).each do |i|
          t = gw <= 1 ? 0.0 : i.to_f / (gw - 1)
          r = (ca.r + (cb.r.to_f - ca.r) * t).clamp(0.0, 65535.0).to_u16
          g = (ca.g + (cb.g.to_f - ca.g) * t).clamp(0.0, 65535.0).to_u16
          b = (ca.b + (cb.b.to_f - ca.b) * t).clamp(0.0, 65535.0).to_u16
          dst[gx + i, y] = StumpyPNG::RGBA.new(r, g, b, 65535_u16)
        end
      end
    end

    # Fill a gap [gx, gx+gw) by extending each neighbour's facing column across
    # its half of the gap (left column over the left half, right over the right).
    # Preserves vertical structure (horizon, deck) without horizontal smearing —
    # a cleaner seed for reference-image editors than a cross-blend.
    def self.fill_edge_extend(dst : StumpyPNG::Canvas, left : StumpyPNG::Canvas, left_x : Int32,
                              right : StumpyPNG::Canvas, right_x : Int32, gx : Int32, gw : Int32, height : Int32)
      mid = gw // 2
      (0...height).each do |y|
        ca = left[left_x, y]
        cb = right[right_x, y]
        (0...gw).each do |i|
          dst[gx + i, y] = i < mid ? ca : cb
        end
      end
    end

    # Build an inpaint mask for a bridge canvas laid out as
    # [ context_a | gap | context_b ]. White = regenerate, black = preserve.
    # A `feather`-pixel gray ramp on each side of the gap softens the seam.
    def self.bridge_mask(width : Int32, height : Int32, context_a : Int32, gap : Int32, feather : Int32) : StumpyPNG::Canvas
      gap_start = context_a
      gap_end = context_a + gap

      mask = StumpyPNG::Canvas.new(width, height, BLACK)
      (0...width).each do |x|
        t = if x >= gap_start && x < gap_end
              1.0
            elsif x >= gap_start - feather && x < gap_start
              feather.zero? ? 1.0 : (x - (gap_start - feather)).to_f / feather
            elsif x >= gap_end && x < gap_end + feather
              feather.zero? ? 1.0 : 1.0 - (x - gap_end).to_f / feather
            else
              0.0
            end
        next if t <= 0.0
        gray = (t.clamp(0.0, 1.0) * 65535).to_u16
        color = StumpyPNG::RGBA.new(gray, gray, gray, 65535_u16)
        (0...height).each { |y| mask[x, y] = color }
      end
      mask
    end
  end
end
