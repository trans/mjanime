require "json"

module MJ
  module Arcana
    # Where the camera stands, and where the light comes from.
    #
    # DataDungeon 0.11.1 stores both as unit vectors and asked `shoot` to accept them and
    # echo back what was asked. The conversions and the sign conventions here are theirs
    # (DESIGN-image-fields.md), reproduced rather than reinvented so the two sides cannot
    # drift:
    #
    #   x = cos(pitch°) · sin(yaw°)          yaw°, pitch° = value × 90°
    #   y = sin(pitch°)
    #   z = ±cos(pitch°) · cos(yaw°)         + front, − back
    #
    # **These fields mean "as asked", never "as measured".** That is not a hedge, it is the
    # nature of the medium: these models take a prompt, not a camera matrix, so the service
    # renders a vector into words and the model complies well but not exactly. A caller
    # treating the echoed value as ground truth for compositing will eventually be out by
    # ten or twenty degrees. DataDungeon has adopted the same reading, and lets a person
    # correct the field in curio.
    #
    # The trap DataDungeon flagged, kept here because it is easy to get backwards: **yaw
    # counts toward the thing's own right on BOTH faces**, so a profile whose nose points
    # LEFT in the picture is showing the thing's RIGHT side, and that is yaw +1.
    struct Direction
      include JSON::Serializable

      getter x : Float64
      getter y : Float64
      getter z : Float64

      def initialize(@x, @y, @z)
      end

      # From the readable form an application holds: side front/back, yaw and pitch in
      # quarter turns.
      def self.from_angles(side : String, yaw : Float64, pitch : Float64) : Direction
        yr = yaw * 90.0 * Math::PI / 180.0
        pr = pitch * 90.0 * Math::PI / 180.0
        sign = side == "back" ? -1.0 : 1.0
        normalise(Math.cos(pr) * Math.sin(yr), Math.sin(pr), sign * Math.cos(pr) * Math.cos(yr))
      end

      def self.normalise(x : Float64, y : Float64, z : Float64) : Direction
        mag = Math.sqrt(x * x + y * y + z * z)
        # A zero vector carries no direction; refuse it rather than divide and emit NaN,
        # which would travel into a caller's record looking like a number.
        raise "direction vector has zero length" if mag < 1e-9
        Direction.new((x / mag).round(4), (y / mag).round(4), (z / mag).round(4))
      end

      def self.from_json_any(node : JSON::Any) : Direction
        if h = node.as_h?
          if h.has_key?("x") && h.has_key?("y") && h.has_key?("z")
            return normalise(num(h["x"]), num(h["y"]), num(h["z"]))
          end
          # The readable form, which is what applications and curio use.
          side = h["side"]?.try(&.as_s?) || "front"
          return from_angles(side, h["yaw"]?.try { |v| num(v) } || 0.0,
            h["pitch"]?.try { |v| num(v) } || 0.0)
        end
        if a = node.as_a?
          raise "a direction array needs three numbers" unless a.size == 3
          return normalise(num(a[0]), num(a[1]), num(a[2]))
        end
        raise "a direction must be {x,y,z}, {side,yaw,pitch} or [x,y,z]"
      end

      private def self.num(v : JSON::Any) : Float64
        v.as_f? || v.as_i?.try(&.to_f) || v.as_s?.try(&.to_f?) ||
          raise "direction components must be numbers"
      end

      def pitch : Float64
        (Math.asin(y.clamp(-1.0, 1.0)) * 180.0 / Math::PI / 90.0).round(3)
      end

      def side : String
        z >= 0 ? "front" : "back"
      end

      def yaw : Float64
        cp = Math.cos(pitch * 90.0 * Math::PI / 180.0)
        return 0.0 if cp.abs < 1e-6 # straight up or down: yaw means nothing
        (Math.asin((x / cp).clamp(-1.0, 1.0)) * 180.0 / Math::PI / 90.0).round(3)
      end

      def to_json_object : Hash(String, JSON::Any)
        {"x" => JSON::Any.new(x), "y" => JSON::Any.new(y), "z" => JSON::Any.new(z)}
      end
    end

    # Rendering a direction into prompt language. The phrasing is deliberately plain and
    # short: Nano and the GPT-Image family follow a few words of direction far better than
    # numeric angles, and an over-specified instruction fights the reference image.
    module ViewWords
      def self.camera(d : Direction, roll : Float64 = 0.0) : String
        parts = [] of String
        parts << face(d)
        if h = height(d)
          parts << h
        end
        if r = tilt(roll)
          parts << r
        end
        parts.join(", ")
      end

      private def self.face(d : Direction) : String
        y = d.yaw.abs
        # Straight down or up: the horizontal bearing is meaningless, so say so instead of
        # emitting a nonsense "from its right".
        return "seen from directly overhead" if d.pitch > 0.95
        return "seen from directly below" if d.pitch < -0.95

        toward = d.yaw > 0 ? "right" : "left"
        back = d.side == "back"
        case
        when y < 0.12
          back ? "seen from directly behind" : "seen from straight on, facing the viewer"
        when y < 0.45
          back ? "seen from behind, turned slightly to show its #{toward} side" : "seen from slightly to its #{toward}"
        when y < 0.8
          back ? "seen from behind at three-quarters, its #{toward} side toward the viewer" : "a three-quarter view from its #{toward}"
        else
          # Its own right side faces us, which means its nose points to the picture's LEFT.
          "seen in full profile, its #{toward} side toward the viewer"
        end
      end

      private def self.height(d : Direction) : String?
        p = d.pitch
        return nil if p.abs < 0.12
        return nil if p.abs > 0.95 # already said by `face`
        case
        when p >= 0.55  then "from high above"
        when p >= 0.12  then "from slightly above"
        when p <= -0.55 then "from low down, looking up"
        else                 "from slightly below"
        end
      end

      private def self.tilt(roll : Float64) : String?
        return nil if roll.abs < 0.1
        deg = (roll * 90).round.to_i
        "the whole image tilted #{deg.abs}° #{roll > 0 ? "clockwise" : "anticlockwise"}"
      end

      # Light is given as the direction it comes FROM, in the picture's own frame.
      def self.light(d : Direction) : String
        vert = case
               when d.y >= 0.55  then "from high above"
               when d.y >= 0.15  then "from above"
               when d.y <= -0.55 then "from below"
               when d.y <= -0.15 then "from slightly below"
               else                   nil
               end
        horiz = case
                when d.x >= 0.15  then "the right"
                when d.x <= -0.15 then "the left"
                else                   nil
                end
        depth = d.z <= -0.5 ? "behind the subject" : nil

        return "lit #{depth}, rim-lit" if depth && !vert && !horiz
        bits = [] of String
        bits << vert if vert
        bits << "from #{horiz}" if horiz
        bits << "from behind" if depth
        return "evenly lit, no strong direction" if bits.empty?
        "lit #{bits.join(" and ")}"
      end
    end
  end
end
