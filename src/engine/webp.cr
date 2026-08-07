module MJ
  # WebP transcoding via ImageMagick. This is a BUILD-TIME tool only: `mj webp` pre-generates a
  # `.webp` next to each library PNG, and the server just serves that file — so the running mj has no
  # image-processing dependency. WebP keeps the alpha channel, and because the keyer already bled the
  # subject colour under transparency (see prop alpha_bleed), lossy webp can't resurrect the key hue.
  module Webp
    def self.tool : String?
      Process.find_executable("magick") || Process.find_executable("convert")
    end

    def self.available? : Bool
      !tool.nil?
    end

    # Encode `src` (PNG, may have alpha) → `dst` (.webp) at the given quality. Returns true on success.
    def self.encode(src : String, dst : String, quality : Int32 = 82) : Bool
      t = tool
      return false unless t
      status = Process.run(t, [src, "-quality", quality.to_s, dst],
        output: Process::Redirect::Close, error: Process::Redirect::Close)
      status.success? && File.exists?(dst)
    end
  end
end
