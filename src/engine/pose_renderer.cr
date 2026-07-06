require "stumpy_png"

module Minanime
  module PoseRenderer
    JOINT_RADIUS = 4
    LIMB_WIDTH   = 4

    # Render a Pose to PNG bytes (black background, colored stick figure)
    def self.render(pose : Pose, width : Int32, height : Int32) : Bytes
      canvas = StumpyPNG::Canvas.new(width, height, StumpyPNG::RGBA.new(0_u16, 0_u16, 0_u16, 65535_u16))

      # Draw limbs first (so joints are on top)
      Pose::LIMB_PAIRS.each_with_index do |(from, to), i|
        kp_a = pose[from]
        kp_b = pose[to]
        next unless kp_a.present? && kp_b.present?

        x1 = (kp_a.x * width).to_i
        y1 = (kp_a.y * height).to_i
        x2 = (kp_b.x * width).to_i
        y2 = (kp_b.y * height).to_i
        r, g, b = Pose::LIMB_COLORS[i]
        color = to_rgba(r, g, b)

        draw_thick_line(canvas, x1, y1, x2, y2, LIMB_WIDTH, color)
      end

      # Draw keypoints
      pose.keypoints.each_with_index do |kp, i|
        next unless kp.present?

        cx = (kp.x * width).to_i
        cy = (kp.y * height).to_i
        r, g, b = Pose::KEYPOINT_COLORS[i]
        color = to_rgba(r, g, b)

        draw_filled_circle(canvas, cx, cy, JOINT_RADIUS, color)
      end

      io = IO::Memory.new
      StumpyPNG.write(canvas, io)
      io.to_slice.dup
    end

    private def self.to_rgba(r : Int32, g : Int32, b : Int32) : StumpyPNG::RGBA
      StumpyPNG::RGBA.new(
        (r * 257).to_u16,
        (g * 257).to_u16,
        (b * 257).to_u16,
        65535_u16
      )
    end

    private def self.draw_filled_circle(canvas : StumpyPNG::Canvas, cx : Int32, cy : Int32, radius : Int32, color : StumpyPNG::RGBA)
      (-radius..radius).each do |dy|
        (-radius..radius).each do |dx|
          if dx * dx + dy * dy <= radius * radius
            px = cx + dx
            py = cy + dy
            if px >= 0 && px < canvas.width && py >= 0 && py < canvas.height
              canvas[px, py] = color
            end
          end
        end
      end
    end

    private def self.draw_thick_line(canvas : StumpyPNG::Canvas, x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32, thickness : Int32, color : StumpyPNG::RGBA)
      half = thickness // 2
      # Draw multiple parallel lines for thickness
      (-half..half).each do |offset|
        dx = x2 - x1
        dy = y2 - y1
        len = Math.sqrt(dx * dx + dy * dy)
        next if len == 0

        # Perpendicular offset
        nx = (-dy / len * offset).to_i
        ny = (dx / len * offset).to_i

        draw_line(canvas, x1 + nx, y1 + ny, x2 + nx, y2 + ny, color)
      end
    end

    # Bresenham's line algorithm
    private def self.draw_line(canvas : StumpyPNG::Canvas, x1 : Int32, y1 : Int32, x2 : Int32, y2 : Int32, color : StumpyPNG::RGBA)
      dx = (x2 - x1).abs
      dy = (y2 - y1).abs
      sx = x1 < x2 ? 1 : -1
      sy = y1 < y2 ? 1 : -1
      err = dx - dy

      x = x1
      y = y1

      loop do
        if x >= 0 && x < canvas.width && y >= 0 && y < canvas.height
          canvas[x, y] = color
        end

        break if x == x2 && y == y2

        e2 = 2 * err
        if e2 > -dy
          err -= dy
          x += sx
        end
        if e2 < dx
          err += dx
          y += sy
        end
      end
    end
  end
end
