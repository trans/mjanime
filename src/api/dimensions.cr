module MJ
  # FLUX.1 models only support these specific dimension pairs
  FLUX1_DIMENSIONS = [
    {1568, 672},
    {1504, 688},
    {1456, 720},
    {1392, 752},
    {1328, 800},
    {1248, 832},
    {1184, 880},
    {1104, 944},
    {1024, 1024},
    {944, 1104},
    {880, 1184},
    {832, 1248},
    {800, 1328},
    {752, 1392},
    {720, 1456},
    {688, 1504},
    {672, 1568},
  ]

  # Supported OUTPUT sizes for Nano Banana (google:4@x / Gemini image). The model
  # rejects any other size with a 400 whose body lists its full supported set.
  # These are the pairs we've confirmed valid in practice.
  # ⚠ 1344×768 and 1536×672 are REJECTED — use 1376×768 and 1548×672 / 1584×672.
  # (Reference INPUT images can be any size; only the requested OUTPUT w/h are fixed.)
  NANO_DIMENSIONS = [
    {1024, 1024},                # 1:1
    {1376, 768}, {768, 1376},    # 16:9 / 9:16
    {1548, 672}, {1584, 672},    # 21:9 (wide panorama)
    {1200, 896}, {896, 1200},    # ~4:3 / 3:4
    {1264, 848}, {848, 1264},    # ~3:2 / 2:3
  ]

  # Nearest supported Nano output size to the requested aspect ratio.
  def self.nano_dimensions(width : Int32, height : Int32) : {Int32, Int32}
    aspect = width.to_f / height
    best = NANO_DIMENSIONS.min_by { |w, h| (w.to_f / h - aspect).abs }
    {best[0], best[1]}
  end

  # Models that require fixed dimension pairs (FLUX.1 family)
  # Kontext models are editors — they handle arbitrary dims, so excluded here
  FIXED_DIMENSION_MODELS = ["runware:100@1", "runware:101@1"]

  def self.snap_dimensions(width : Int32, height : Int32, model : String = "") : {Int32, Int32}
    if FIXED_DIMENSION_MODELS.any? { |m| model.starts_with?(m) }
      # FLUX.1 models: snap to nearest supported pair by aspect ratio
      aspect = width.to_f / height.to_f
      best = FLUX1_DIMENSIONS.min_by do |w, h|
        (w.to_f / h.to_f - aspect).abs
      end
      {best[0], best[1]}
    else
      # FLUX.2+ models: just align to multiples of 16
      w = ((width + 8) // 16) * 16
      h = ((height + 8) // 16) * 16
      w = w.clamp(64, 2048)
      h = h.clamp(64, 2048)
      {w, h}
    end
  end
end
