require "stumpy_png"

module Minanime
  # Pixel-art restyle via Nano Banana 2 (google:4@3), with optional transparency keying
  # and an optional deterministic pixel-perfect "snap" pass.
  #
  # Stage 1 (the look): the AI redraws the image as 8-bit / 16-bit pixel art — driven by the
  #   style prompt, NOT by numeric knobs. Requires the current model (4@3/4@2); the old
  #   google:4@1 refuses restyles.
  # Stage 2 (optional authenticity): downscale to a true grid + quantize to N colours +
  #   nearest upscale. Works cleanly here precisely because Stage 1 already drew pixel-art
  #   forms. Uses ImageMagick (`magick`).
  module Pixelize
    CHROMA = [255, 0, 255] # magenta chroma field for transparent-background keying

    def self.style_prompt(style : String) : String
      case style.downcase
      when "8bit", "8-bit"
        "Redraw in an 8-bit pixel art style, NES era, with chunky blocky pixels and a " \
        "small limited color palette (NOT just a pixelation)."
      else # 16bit
        "Redraw in a 16-bit pixel art style, SNES era, with clean pixels, pixel shading " \
        "and a limited palette (NOT just a pixelation)."
      end
    end

    def self.build_prompt(spec : PixelSpec) : String
      prompt = style_prompt(spec.style)
      case spec.background
      when "transparent"
        prompt += " Place the artwork on a solid flat magenta (#FF00FF) background, nothing else."
      when "keep"
        # let the model choose its own background
      else
        prompt += " Place the artwork on a solid flat #{spec.background} background, nothing else."
      end
      prompt += " #{spec.prompt}" unless spec.prompt.strip.empty?
      prompt
    end

    # Stage 1: raw AI redraw. Returns the PNG bytes as generated.
    def self.redraw(client : RunwareClient, image_bytes : Bytes, spec : PixelSpec) : Bytes
      res = client.edit_references([image_bytes], build_prompt(spec), spec.width, spec.height, spec.model)
      res.image_data
    end

    # Stage 2: turn a raw redraw into the final sprite (snap + background keying).
    def self.finish(redraw_bytes : Bytes, spec : PixelSpec) : StumpyPNG::Canvas
      canvas = CanvasUtil.from_png_bytes(redraw_bytes)
      canvas = snap(canvas, spec.grid, spec.colors) if spec.snap        # quantise on opaque art first
      canvas = key_color(canvas, CHROMA, 40.0, 110.0) if spec.background == "transparent"
      canvas
    end

    # Distance-from-colour alpha key (drops the flat chroma background to transparent).
    def self.key_color(src : StumpyPNG::Canvas, bg : Array(Int32), lo : Float64, hi : Float64) : StumpyPNG::Canvas
      w = src.width
      h = src.height
      span = (hi - lo).abs < 1e-6 ? 1.0 : (hi - lo)
      dst = StumpyPNG::Canvas.new(w, h)
      (0...h).each do |y|
        (0...w).each do |x|
          px = src[x, y]
          dr = ((px.r // 257).to_i - bg[0]).abs
          dg = ((px.g // 257).to_i - bg[1]).abs
          db = ((px.b // 257).to_i - bg[2]).abs
          dist = {dr, dg, db}.max.to_f
          t = ((dist - lo) / span).clamp(0.0, 1.0)
          a = (t * t * (3.0 - 2.0 * t) * 65535.0).to_u16 # smoothstep
          dst[x, y] = StumpyPNG::RGBA.new(px.r, px.g, px.b, a)
        end
      end
      dst
    end

    # Deterministic pixel-perfect pass via ImageMagick: downscale to `grid`, quantise to
    # `colors` (flat, no dither), nearest-upscale back to the canvas size.
    def self.snap(src : StumpyPNG::Canvas, grid : Int32, colors : Int32) : StumpyPNG::Canvas
      w = src.width
      h = src.height
      args = ["png:-",
              "-resize", "#{grid}x#{grid}",
              "-dither", "None", "-colors", colors.to_s,
              "-filter", "point", "-resize", "#{w}x#{h}",
              "png:-"]
      snapped = run_magick(CanvasUtil.to_png_bytes(src), args)
      CanvasUtil.from_png_bytes(snapped)
    end

    private def self.run_magick(input : Bytes, args : Array(String)) : Bytes
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = begin
        Process.run("magick", args, input: IO::Memory.new(input), output: stdout, error: stderr)
      rescue File::NotFoundError
        raise "snap requires ImageMagick (`magick`) on PATH; set snap: false to skip it."
      end
      raise "ImageMagick snap failed: #{stderr}" unless status.success?
      stdout.to_slice.dup
    end
  end
end
