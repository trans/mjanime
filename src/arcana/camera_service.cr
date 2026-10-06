require "arcana-core"
require "base64"
require "json"
require "./cameras"
require "./xcf"

module MJ
  module Arcana
    # The camera service: pick a camera, hand it a prompt and a reference, get a picture.
    #
    # The point is that the caller supplies intent and nothing else. Geometry rules,
    # per-model parameter spelling, which models silently discard a reference, and what a
    # moderation refusal looks like all live in the registry rather than in every caller.
    module CameraService
      SHOOT_SCHEMA = JSON.parse(%<{
        "type":"object",
        "required":["prompt"],
        "description":"Draw a picture with the named camera. If a reference image is supplied the subject is carried into a NEW pose rather than reproduced — that is what the reference is for. Returns base64 unless output_path is given; bus services do not share a filesystem, so base64 is the portable answer.",
        "properties":{
          "camera":{"type":"string","description":"Camera id — call `cameras` for the list. Default 'klein' (cheapest that holds a character)."},
          "prompt":{"type":"string","description":"What to draw. If you pass a reference, say 'in the same style' rather than describing the style: an over-specified style fights the reference image."},
          "reference_base64":{"type":"string","description":"Reference image as base64 (PNG). The subject to carry into the new picture."},
          "reference_path":{"type":"string","description":"Reference image path — ONLY works if the caller shares a filesystem with this service. Prefer reference_base64."},
          "width":{"type":"integer","description":"Desired width; snapped to the camera's nearest supported aspect. Default 1024."},
          "height":{"type":"integer","description":"Desired height; snapped. Default 1024."},
          "format":{"type":"string","enum":["webp","png","jpg","xcf"],"description":"Default webp: ~26x smaller on the wire than png for the same picture, and unlike jpg it keeps hard ink edges clean and supports transparency. Use png for lossless; jpg only for photographic subjects (its ringing lands on the black outlines comic art is made of). xcf is GIMP's TILED format — far bigger, but two revisions of the same picture share ~98% of their chunks under content-defined chunking, so it is the right choice for art that will be edited repeatedly and stored in a deduplicating store. Adds ~1.4s for the GIMP conversion."},
          "output_path":{"type":"string","description":"Write the image here instead of returning base64."}
        }
      }>)

      CAMERAS_SCHEMA = JSON.parse(%<{"type":"object","properties":{}}>)

      def self.register(ts : ::Arcana::Toolset, rw : RunwareClient)
        ts.tool("cameras",
          "List the available cameras with measured cost, speed and character.",
          input_schema: CAMERAS_SCHEMA) { |_| handle_cameras }
        ts.tool("shoot",
          "Draw a picture with a chosen camera, optionally carrying a character from a reference image.",
          input_schema: SHOOT_SCHEMA) { |data| handle_shoot(rw, data) }
      end

      def self.handle_cameras : JSON::Any
        JSON.parse({
          "cameras" => Cameras.list.map do |c|
            {
              "id"       => c.id,
              "label"    => c.label,
              "model"    => c.model,
              "usd"      => c.cost,
              "seconds"  => c.seconds,
              "sizes"    => c.sizes,
              "note"     => c.note,
            }
          end,
          "note" => "Costs and timings are measured from live calls, not quoted from docs.",
        }.to_json)
      end

      def self.handle_shoot(rw : RunwareClient, data : JSON::Any) : JSON::Any
        prompt = data["prompt"]?.try(&.as_s?) || raise "shoot requires 'prompt'"
        id = data["camera"]?.try(&.as_s?) || "klein"
        cam = Cameras.find(id) || raise "unknown camera #{id.inspect} — call `cameras` for the list"

        ref = reference_bytes(data)
        if ref && Cameras::REFERENCE_BLIND.includes?(cam.model)
          raise "#{cam.label} silently discards reference images — it would bill you for a " \
                "picture that ignores the subject. Choose another camera."
        end

        w, h = cam.snap(
          data["width"]?.try(&.as_i?) || 1024,
          data["height"]?.try(&.as_i?) || 1024)

        # Runware accepts JPG, JPEG, PNG and WEBP (its own default is JPG). We default to
        # webp: far smaller than png, and unlike jpg it is alpha-capable and does not ring
        # along hard black outlines — which is most of what comic art is made of.
        fmt = (data["format"]?.try(&.as_s?) || "webp").downcase
        fmt = "jpg" if fmt == "jpeg"
        raise "format must be webp, png, jpg or xcf" unless {"webp", "png", "jpg", "xcf"}.includes?(fmt)
        if fmt == "xcf" && !Xcf.available?
          raise "xcf needs gimp-console on this host, which is not installed"
        end
        # Runware cannot emit XCF; ask it for lossless PNG and convert locally.
        wire_fmt = fmt == "xcf" ? "png" : fmt

        result = rw.edit_references([ref] of Bytes, prompt, w, h, cam.model,
          cam.extra, wire_fmt.upcase) if ref
        result ||= rw.edit_references([blank_canvas(w, h)], prompt, w, h, cam.model,
          cam.extra, wire_fmt.upcase)

        img = result.image_data
        img = Xcf.convert(img) if fmt == "xcf"
        res = {
          "camera"  => JSON::Any.new(cam.id),
          "model"   => JSON::Any.new(cam.model),
          "width"   => JSON::Any.new(w.to_i64),
          "height"  => JSON::Any.new(h.to_i64),
          "bytes"   => JSON::Any.new(img.size.to_i64),
          "usd"     => JSON::Any.new(result.cost || cam.cost),
        } of String => JSON::Any

        if path = data["output_path"]?.try(&.as_s?)
          File.write(path, img)
          res["output_path"] = JSON::Any.new(path)
        else
          res["image_base64"] = JSON::Any.new(Base64.strict_encode(img))
          res["content_type"] = JSON::Any.new(
            case fmt
            when "webp" then "image/webp"
            when "jpg"  then "image/jpeg"
            when "xcf"  then "image/x-xcf"
            else             "image/png"
            end)
        end
        JSON::Any.new(res)
      end

      private def self.reference_bytes(data : JSON::Any) : Bytes?
        if b64 = data["reference_base64"]?.try(&.as_s?)
          return Base64.decode(b64)
        end
        if path = data["reference_path"]?.try(&.as_s?)
          unless File.exists?(path)
            raise "reference_path #{path.inspect} is not visible to this service. Bus services " \
                  "are filesystem-isolated — pass reference_base64 instead."
          end
          return File.read(path).to_slice
        end
        nil
      end

      # A flat canvas stands in for "no reference". Runware's img2img path always wants a
      # seed image, and the reference-edit endpoint is the only text-to-image route we have.
      private def self.blank_canvas(w : Int32, h : Int32) : Bytes
        canvas = StumpyCore::Canvas.new(w, h, StumpyCore::RGBA.from_rgb8(128, 128, 128))
        CanvasUtil.to_png_bytes(canvas)
      end
    end
  end
end
