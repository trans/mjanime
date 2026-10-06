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

      # A provider's content filter refusing is NOT an error: it is unbilled, it is
      # probabilistic (Nano refuses the same prompt it accepted minutes earlier), and the
      # caller's right response is a retry or a tamer prompt — not a failure. It gets its
      # own outcome so callers can tell the two apart.
      # Each provider words it differently, and the error CODE is no help: OpenAI returns
      # the same `providerBadRequest` for a refusal as for a bad parameter, so matching on
      # the code would misfile real errors as refusals. Match the safety language instead.
      # These were all collected from live refusals; don't add one speculatively.
      REFUSAL_MARKERS = [
        # Google / Nano Banana
        "invalidProviderContent", "content moderation", "Responsible AI",
        "flagged and rejected", "could not generate the image",
        # OpenAI (GPT-Image 2.5 and 1.5)
        "rejected by the safety system", "safety_violations",
        "content_policy_violation", "safety system",
      ]

      def self.refusal?(message : String) : Bool
        REFUSAL_MARKERS.any? { |m| message.includes?(m) }
      end

      # The provider's own refusal text is long, carries a support URL and a request id,
      # and buries the one part a caller can act on. Pull the violated category out when
      # OpenAI names it — a caller retrying automatically needs to know whether it tripped
      # self-harm or violence, not read prose.
      def self.refusal_categories(message : String) : Array(String)
        if m = message.match(/safety_violations=\[([^\]]*)\]/)
          m[1].split(",").map(&.strip).reject(&.empty?)
        else
          [] of String
        end
      end

      def self.handle_cameras : JSON::Any
        JSON.parse({
          "cameras" => Cameras.list.map do |c|
            {
              "id"      => c.id,
              "label"   => c.label,
              "model"   => c.model,
              "usd"     => c.cost,
              "seconds" => c.seconds,
              "sizes"   => c.sizes,
              "quality" => c.quality,
              "version" => c.version,
              "note"    => c.note,
            }
          end,
          "note" => "Costs and timings are MEASURED from live calls, not quoted from docs. " \
                    "`quality` is a rank (higher is better), a judgement over the model survey " \
                    "rather than a measurement — reuse may prefer a higher rank when several " \
                    "cached pictures match. `version` bumps when anything that changes a " \
                    "camera's output changes, so caches know its old pictures are stale.",
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

        # A caller-supplied seed makes a shot reproducible, which is also what the
        # same-seed A/B in notes/verify_param.py needs.
        extra = cam.extra.dup
        if seed = data["seed"]?.try(&.as_i64?)
          extra["seed"] = JSON::Any.new(seed)
        end

        begin
          result = rw.edit_references([ref] of Bytes, prompt, w, h, cam.model,
            extra, wire_fmt.upcase) if ref
          result ||= rw.edit_references([blank_canvas(w, h)], prompt, w, h, cam.model,
            extra, wire_fmt.upcase)
        rescue ex
          msg = ex.message || "unknown"
          raise ex unless refusal?(msg)
          # Unbilled. Report it as an outcome, not a failure, and never fall back to
          # another camera — a silent substitution would corrupt the caller's logs.
          return JSON::Any.new({
            "status"     => JSON::Any.new("refused"),
            "camera"     => JSON::Any.new(cam.id),
            "model"      => JSON::Any.new(cam.model),
            "version"    => JSON::Any.new(cam.version.to_i64),
            "usd"        => JSON::Any.new(0.0),
            "reason"     => JSON::Any.new(msg[0, 400]),
            "categories" => JSON::Any.new(
              refusal_categories(msg).map { |c| JSON::Any.new(c) }),
            "retry" => JSON::Any.new(true),
            "note"  => JSON::Any.new(
              "The provider's content filter refused. Not billed. Refusals are " \
              "probabilistic — the same prompt may pass on a retry. A tamer prompt or a " \
              "different camera also works."),
          } of String => JSON::Any)
        end

        img = result.image_data
        img = Xcf.convert(img) if fmt == "xcf"
        res = {
          "status"  => JSON::Any.new("ok"),
          "camera"  => JSON::Any.new(cam.id),
          "version" => JSON::Any.new(cam.version.to_i64),
          "model"   => JSON::Any.new(cam.model),
          "width"   => JSON::Any.new(w.to_i64),
          "height"  => JSON::Any.new(h.to_i64),
          "bytes"   => JSON::Any.new(img.size.to_i64),
          "format"  => JSON::Any.new(fmt),
          # What the provider actually billed. nil means it reported no price, which is
          # recorded as unpriced — never silently as the camera's average, which would put
          # a guess into the caller's ledger as if it were fact.
          "usd"           => result.cost ? JSON::Any.new(result.cost) : JSON::Any.new(nil),
          "usd_estimated" => JSON::Any.new(result.cost ? false : true),
        } of String => JSON::Any
        res["usd"] = JSON::Any.new(cam.cost) unless result.cost
        if seed = data["seed"]?.try(&.as_i64?)
          res["seed"] = JSON::Any.new(seed)
        end

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
