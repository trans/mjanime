module Minanime
  # Builds one long seamless scenery image from a folder of ordered source PNGs.
  #
  #   1. Stylize each source (img2img) to a common height.
  #   2. Between each neighbouring pair, invent transition terrain by inpainting
  #      a gap whose edges are seeded with the two neighbours' facing edges.
  #   3. Concatenate: tile | bridge | tile | bridge | ... into one strip.
  class StripBuilder
    def initialize(@client : RunwareClient)
    end

    def build(source_dir : String, script : StripScript, out_path : String, &block : String ->)
      sources = resolve_sources(source_dir, script)
      raise "Need at least 2 source PNGs in #{source_dir} (found #{sources.size})" if sources.size < 2

      height = snap64(script.height || infer_height(sources))
      yield "Using #{sources.size} tiles at height #{height}px"

      # 1. Prepare tiles: either stylized (img2img) or passed through untouched.
      tiles = sources.map_with_index do |path, i|
        if script.passthrough
          yield "Loading #{i + 1}/#{sources.size}: #{File.basename(path)} (passthrough)"
          load_tile(path, height)
        else
          yield "Stylizing #{i + 1}/#{sources.size}: #{File.basename(path)}"
          stylize(path, script, height)
        end
      end

      # 2. Interleave tiles with invented bridges.
      parts = [] of StumpyPNG::Canvas
      tiles.each_with_index do |tile, i|
        parts << tile
        next if i == tiles.size - 1
        yield "Bridging tile #{i + 1} -> #{i + 2}"
        parts << build_bridge(tile, tiles[i + 1], script, height)
      end

      # 3. Stitch and write.
      strip = CanvasUtil.hconcat(parts)
      CanvasUtil.write_png_file(strip, out_path)
      yield "Wrote #{out_path} (#{strip.width}x#{strip.height})"
    end

    private def resolve_sources(dir : String, script : StripScript) : Array(String)
      if names = script.sources
        names.map { |n| File.join(dir, n) }.tap do |paths|
          paths.each { |p| raise "Source not found: #{p}" unless File.exists?(p) }
        end
      else
        Dir.glob(File.join(dir, "*.png"))
          .reject { |p| %w[strip.png].includes?(File.basename(p)) }
          .sort
      end
    end

    private def infer_height(sources : Array(String)) : Int32
      heights = sources.map { |p| CanvasUtil.from_png_file(p).height }.sort!
      heights[heights.size // 2]
    end

    # Load a source untouched, resized to the common height (aspect preserved).
    private def load_tile(path : String, height : Int32) : StumpyPNG::Canvas
      src = CanvasUtil.from_png_file(path)
      return src if src.height == height
      w = (height.to_f * src.width / src.height).to_i
      CanvasUtil.resize(src, w, height)
    end

    # img2img restyle of one source, output normalized to `height`.
    private def stylize(path : String, script : StripScript, height : Int32) : StumpyPNG::Canvas
      src = CanvasUtil.from_png_file(path)
      tile_w = snap64(script.tile_width || (height.to_f * src.width / src.height).to_i)

      request = GenerationRequest.new(
        prompt: script.style_prompt,
        seed_image: path,
        seed_is_uuid: false,
        width: tile_w,
        height: height,
        model: script.tile_model,
        strength: script.tile_strength,
        steps: script.tile_steps,
        cfg_scale: script.tile_cfg_scale,
        negative_prompt: script.negative_prompt
      )
      result = @client.generate(request)
      CanvasUtil.from_png_bytes(result.image_data)
    end

    # Invent the terrain that joins tile_a's right edge to tile_b's left edge.
    # Returns just the gap-width middle strip of the inpaint result.
    private def build_bridge(tile_a : StumpyPNG::Canvas, tile_b : StumpyPNG::Canvas,
                             script : StripScript, height : Int32) : StumpyPNG::Canvas
      ctx = snap64(script.context_width)
      gap = snap64(script.gap_width)
      canvas_w = ctx + gap + ctx

      edge_a = CanvasUtil.crop(tile_a, tile_a.width - ctx, 0, ctx, height)
      edge_b = CanvasUtil.crop(tile_b, 0, 0, ctx, height)

      seed = StumpyPNG::Canvas.new(canvas_w, height, CanvasUtil::BLACK)
      CanvasUtil.paste(seed, edge_a, 0, 0)
      CanvasUtil.paste(seed, edge_b, ctx + gap, 0)

      # Pre-fill the gap so the generator has real pixels (horizon, colours) to
      # build on. Reference editors (Nano) preserve horizontal smears as streaks,
      # so extend edge columns for them; mask inpainters (FLUX) prefer a blend.
      rendered = if script.bridge_model.starts_with?("google:")
                   CanvasUtil.fill_edge_extend(seed, tile_a, tile_a.width - 1, tile_b, 0, ctx, gap, height)
                   bridge_nano(seed, canvas_w, height, script)
                 else
                   CanvasUtil.fill_hblend(seed, tile_a, tile_a.width - 1, tile_b, 0, ctx, gap, height)
                   bridge_inpaint(seed, canvas_w, height, ctx, gap, script)
                 end

      CanvasUtil.crop(rendered, ctx, 0, gap, height)
    end

    # Mask-inpaint bridge (FLUX Fill etc.): white gap regenerated, edges preserved.
    private def bridge_inpaint(seed : StumpyPNG::Canvas, canvas_w : Int32, height : Int32,
                               ctx : Int32, gap : Int32, script : StripScript) : StumpyPNG::Canvas
      mask = CanvasUtil.bridge_mask(canvas_w, height, ctx, gap, script.feather)
      result = @client.inpaint(
        CanvasUtil.to_png_bytes(seed),
        CanvasUtil.to_png_bytes(mask),
        script.bridge_prompt!,
        canvas_w, height,
        script.bridge_model,
        steps: script.bridge_steps,
        strength: script.bridge_strength,
        cfg_scale: script.tile_cfg_scale,
        negative_prompt: script.negative_prompt
      )
      CanvasUtil.from_png_bytes(result.image_data)
    end

    # Reference-image bridge (Nano Banana): feed the composite as a reference and
    # instruct the model to repaint only the middle strip, matching the source
    # art style exactly. Result is resized back to the canvas so the crop lines up.
    private def bridge_nano(seed : StumpyPNG::Canvas, canvas_w : Int32, height : Int32,
                            script : StripScript) : StumpyPNG::Canvas
      instruction = String.build do |s|
        s << "This image shows a real illustrated scene on the far left and far right, "
        s << "with a rough blended placeholder strip in the middle. "
        s << "Repaint ONLY the middle strip so the left side flows into the right side as "
        s << "one single continuous seamless scene: " << script.bridge_prompt! << ". "
        s << "Exactly match the art style, line quality, colour palette, shading, lighting "
        s << "and horizon of the left and right sides. Keep the left and right areas unchanged. "
        s << "No text, no signs, no lettering."
      end
      # Nano Banana only supports a fixed set of output sizes; request the one
      # nearest our canvas aspect, then resize the result back so the crop aligns.
      rw, rh = nano_dimensions(canvas_w, height)
      result = @client.edit_references([CanvasUtil.to_png_bytes(seed)], instruction, rw, rh, script.bridge_model)
      rendered = CanvasUtil.from_png_bytes(result.image_data)
      CanvasUtil.resize(rendered, canvas_w, height)
    end

    # Supported output sizes for google:4@x (Nano Banana / Gemini Flash Image).
    NANO_DIMENSIONS = [
      {1024, 1024}, {1248, 832}, {832, 1248}, {1184, 864}, {864, 1184},
      {896, 1152}, {1152, 896}, {768, 1344}, {1344, 768}, {1536, 672},
    ]

    private def nano_dimensions(width : Int32, height : Int32) : Tuple(Int32, Int32)
      aspect = width.to_f / height
      NANO_DIMENSIONS.min_by { |w, h| (w.to_f / h - aspect).abs }
    end

    private def snap64(n : Int32) : Int32
      (((n + 32) // 64) * 64).clamp(64, 2048)
    end
  end
end
