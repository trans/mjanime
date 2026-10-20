module MJ
  # Supported OUTPUT sizes for Nano Banana (google:4@x / Gemini image). The model
  # rejects any other size with a 400 whose body lists its full supported set.
  # These are the pairs we've confirmed valid in practice.
  # ⚠ 1344×768 and 1536×672 are REJECTED — use 1376×768 and 1548×672 / 1584×672.
  # (Reference INPUT images can be any size; only the requested OUTPUT w/h are fixed.)
  NANO_DIMENSIONS = [
    {1024, 1024},             # 1:1
    {1376, 768}, {768, 1376}, # 16:9 / 9:16
    {1548, 672}, {1584, 672}, # 21:9 (wide panorama)
    {1200, 896}, {896, 1200}, # ~4:3 / 3:4
    {1264, 848}, {848, 1264}, # ~3:2 / 2:3
  ]

  # Nearest supported Nano output size to the requested aspect ratio.
  def self.nano_dimensions(width : Int32, height : Int32) : {Int32, Int32}
    aspect = width.to_f / height
    best = NANO_DIMENSIONS.min_by { |w, h| (w.to_f / h - aspect).abs }
    {best[0], best[1]}
  end

  # FLUX.1 schnell and dev, on Runware. Kontext models are editors that take any size, so
  # they aren't here.
  FLUX1_MODELS = ["runware:100@1", "runware:101@1"]

  def self.snap_dimensions(width : Int32, height : Int32, model : String = "") : {Int32, Int32}
    if FLUX1_MODELS.any? { |m| model.starts_with?(m) }
      # FLUX.1: each side a multiple of 64, from 128 to 2048 (Runware's 400 says so; both
      # models, 2026-10-20). This snapped to a list of pairs once, BFL's Kontext sizes
      # (1568x672, 1504x688, ...), whose sides are multiples of 32 and which Runware now
      # refuses; any multiple of 64 goes, 1344x768 among them.
      w = (((width + 32) // 64) * 64).clamp(128, 2048)
      h = (((height + 32) // 64) * 64).clamp(128, 2048)
      {w, h}
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
