require "json"

module MJ
  struct Keypoint
    include JSON::Serializable

    property x : Float64
    property y : Float64
    property confidence : Float64

    def initialize(@x = 0.0, @y = 0.0, @confidence = 0.0)
    end

    def present? : Bool
      confidence > 0.0
    end

    def self.interpolate(a : Keypoint, b : Keypoint, t : Float64) : Keypoint
      return b unless a.present?
      return a unless b.present?
      Keypoint.new(
        x: a.x + (b.x - a.x) * t,
        y: a.y + (b.y - a.y) * t,
        confidence: a.confidence + (b.confidence - a.confidence) * t
      )
    end
  end

  class Pose
    include JSON::Serializable

    property keypoints : Array(Keypoint)

    # COCO 18-keypoint names
    KEYPOINT_NAMES = [
      "nose",            # 0
      "neck",            # 1
      "right_shoulder",  # 2
      "right_elbow",     # 3
      "right_wrist",     # 4
      "left_shoulder",   # 5
      "left_elbow",      # 6
      "left_wrist",      # 7
      "right_hip",       # 8
      "right_knee",      # 9
      "right_ankle",     # 10
      "left_hip",        # 11
      "left_knee",       # 12
      "left_ankle",      # 13
      "right_eye",       # 14
      "left_eye",        # 15
      "right_ear",       # 16
      "left_ear",        # 17
    ]

    KEYPOINT_INDEX = KEYPOINT_NAMES.each_with_index.to_h

    # 17 limb connections [from, to]
    LIMB_PAIRS = [
      {1, 0},   # neck -> nose
      {1, 2},   # neck -> right shoulder
      {1, 5},   # neck -> left shoulder
      {2, 3},   # right shoulder -> right elbow
      {3, 4},   # right elbow -> right wrist
      {5, 6},   # left shoulder -> left elbow
      {6, 7},   # left elbow -> left wrist
      {1, 8},   # neck -> right hip
      {8, 9},   # right hip -> right knee
      {9, 10},  # right knee -> right ankle
      {1, 11},  # neck -> left hip
      {11, 12}, # left hip -> left knee
      {12, 13}, # left knee -> left ankle
      {0, 14},  # nose -> right eye
      {14, 16}, # right eye -> right ear
      {0, 15},  # nose -> left eye
      {15, 17}, # left eye -> left ear
    ]

    # Rainbow gradient colors for keypoints (R, G, B)
    KEYPOINT_COLORS = [
      {255, 0, 0},     # 0  nose
      {255, 85, 0},    # 1  neck
      {255, 170, 0},   # 2  right shoulder
      {255, 255, 0},   # 3  right elbow
      {170, 255, 0},   # 4  right wrist
      {85, 255, 0},    # 5  left shoulder
      {0, 255, 0},     # 6  left elbow
      {0, 255, 85},    # 7  left wrist
      {0, 255, 170},   # 8  right hip
      {0, 255, 255},   # 9  right knee
      {0, 170, 255},   # 10 right ankle
      {0, 85, 255},    # 11 left hip
      {0, 0, 255},     # 12 left knee
      {85, 0, 255},    # 13 left ankle
      {170, 0, 255},   # 14 right eye
      {255, 0, 255},   # 15 left eye
      {255, 0, 170},   # 16 right ear
      {255, 0, 85},    # 17 left ear
    ]

    # Colors for each limb connection
    LIMB_COLORS = [
      {0, 0, 153},     # neck -> nose
      {153, 0, 0},     # neck -> right shoulder
      {153, 51, 0},    # neck -> left shoulder
      {153, 102, 0},   # right shoulder -> right elbow
      {153, 153, 0},   # right elbow -> right wrist
      {102, 153, 0},   # left shoulder -> left elbow
      {51, 153, 0},    # left elbow -> left wrist
      {0, 153, 0},     # neck -> right hip
      {0, 153, 51},    # right hip -> right knee
      {0, 153, 102},   # right knee -> right ankle
      {0, 153, 153},   # neck -> left hip
      {0, 102, 153},   # left hip -> left knee
      {0, 51, 153},    # left knee -> left ankle
      {51, 0, 153},    # nose -> right eye
      {102, 0, 153},   # right eye -> right ear
      {153, 0, 153},   # nose -> left eye
      {153, 0, 102},   # left eye -> left ear
    ]

    def initialize(@keypoints = Array(Keypoint).new(18) { Keypoint.new })
    end

    def [](index : Int32) : Keypoint
      @keypoints[index]
    end

    def [](name : String) : Keypoint
      idx = KEYPOINT_INDEX[name]?
      raise "Unknown keypoint: #{name}" unless idx
      @keypoints[idx]
    end

    def []=(name : String, value : Keypoint)
      idx = KEYPOINT_INDEX[name]?
      raise "Unknown keypoint: #{name}" unless idx
      @keypoints[idx] = value
    end

    def []=(index : Int32, value : Keypoint)
      @keypoints[index] = value
    end

    # Apply joint overrides from a hash like {"right_wrist": [0.6, 0.5]}
    def with_overrides(joints : Hash(String, Array(Float64))) : Pose
      result = Pose.new(@keypoints.dup)
      joints.each do |name, coords|
        idx = KEYPOINT_INDEX[name]?
        next unless idx
        result[idx] = Keypoint.new(x: coords[0], y: coords[1], confidence: 1.0)
      end
      result
    end

    # Linear interpolation between two poses
    def self.interpolate(a : Pose, b : Pose, t : Float64) : Pose
      kps = (0...18).map do |i|
        Keypoint.interpolate(a[i], b[i], t)
      end
      Pose.new(kps)
    end

    # Create from Runware preprocess response (flat array: [x0,y0,c0, x1,y1,c1, ...])
    def self.from_flat_array(data : Array(Float64), width : Int32, height : Int32) : Pose
      kps = (0...18).map do |i|
        base = i * 3
        if base + 2 < data.size
          # Normalize to 0.0-1.0
          Keypoint.new(
            x: data[base] / width,
            y: data[base + 1] / height,
            confidence: data[base + 2]
          )
        else
          Keypoint.new
        end
      end
      Pose.new(kps)
    end
  end
end
