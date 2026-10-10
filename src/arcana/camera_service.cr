require "arcana-core"
require "base64"
require "json"
require "./cameras"
require "./transport"
require "./xcf"
require "./convert"
require "./view"

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
          "format":{"type":"string","enum":["webp","png","jpg","xcf"],"description":"Default webp: ~26x smaller on the wire than png for the same picture, and unlike jpg it keeps hard ink edges clean. Note Runware returns LOSSY webp with NO alpha channel (verified: a VP8 chunk, no VP8X) — it is the right default for serve-and-display, but do not plan on transparency or re-key a webp. Use png for lossless and for anything with an alpha channel; jpg only for photographic subjects (its ringing lands on the black outlines comic art is made of). xcf is GIMP's TILED format — far bigger, but two revisions of the same picture share ~98% of their chunks under content-defined chunking, so it is the right choice for art that will be edited repeatedly and stored in a deduplicating store. Adds ~1.4s for the GIMP conversion."},
          "view":{"description":"Where the camera stands, as a unit vector {x,y,z}, or the readable form {side:'front'|'back',yaw:-1..1,pitch:-1..1} (quarter turns). Rendered into prompt words — these models take a prompt, not a camera matrix, so this is AS ASKED and not exact. Echoed back."},
          "view_roll":{"type":"number","description":"Image turned in its own plane, quarter turns, -2..2."},
          "light":{"description":"Where the light comes FROM, in the picture's frame, same shapes as `view`. Also as-asked."},
          "output_path":{"type":"string","description":"Write the image here instead of returning base64."}
        }
      }>)

      CAMERAS_SCHEMA = JSON.parse(%<{"type":"object","properties":{}}>)

      # Transports are passed as a map so a camera is served by whichever one it names.
      # Today there is exactly one; see transport.cr for why recording that still matters.
      def self.register(ts : ::Arcana::Toolset, rw : RunwareClient)
        register(ts, {"runware" => RunwareTransport.new(rw).as(Transport)})
      end

      def self.register(ts : ::Arcana::Toolset, transports : Hash(String, Transport))
        ts.tool("cameras",
          "List the available cameras with measured cost, speed and character.",
          input_schema: CAMERAS_SCHEMA) { |_| handle_cameras }
        ts.tool("shoot",
          "Draw a picture with a chosen camera, optionally carrying a character from a reference image.",
          input_schema: SHOOT_SCHEMA) { |data| handle_shoot(transports, data) }
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
      # A third outcome, distinct from both success and refusal: Runware's queue beat us.
      #
      # Runware enforces no hard rate limit — it runs a shared queue, so heavy traffic shows
      # up as latency, and capacity exhaustion arrives as 429 or, as measured here, 504.
      # The client already retries these with backoff; this is what is left when the retries
      # are used up. It is unbilled, it is transient, and the caller's move is to wait and
      # try again — which is a different instruction from a refusal (reword it) and from an
      # error (stop).
      OVERLOAD_STATUSES = [408, 429, 500, 502, 503, 504]

      def self.overloaded?(message : String) : Bool
        if m = message.match(/Runware (?:API|upload|preprocess) error \((\d{3})\)/)
          OVERLOAD_STATUSES.includes?(m[1].to_i)
        else
          false
        end
      end

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
              "id"       => c.id,
              "label"    => c.label,
              "model"    => c.model,
              "usd"      => c.cost,
              "seconds"  => c.seconds,
              "sizes"    => c.sizes,
              "quality"  => c.quality,
              "version"  => c.version,
              "provider" => c.provider,
              "note"     => c.note,
            }
          end,
          # A caller planning for a spike needs this, and it is not guessable from the
          # model ids: google:/openai:/bfl: cameras all reach their provider THROUGH
          # Runware, so they share one queue on one account.
          "pools"      => Cameras.pools,
          "pools_note" => "Cameras grouped by transport. Cameras in the SAME group share one " \
                          "endpoint, one account and one queue, so switching between them does " \
                          "not route around congestion — a model id of google:/openai:/bfl: " \
                          "names the MODEL, not an independent capacity pool. Only cameras in " \
                          "DIFFERENT groups are independent.",
          "note" => "Costs and timings are MEASURED from live calls, not quoted from docs. " \
                    "`quality` is a rank (higher is better), a judgement over the model survey " \
                    "rather than a measurement — reuse may prefer a higher rank when several " \
                    "cached pictures match. `version` bumps when anything that changes a " \
                    "camera's output changes. It is PROVENANCE, not a quality signal: it " \
                    "says the configuration differed and implies nothing about better or " \
                    "worse, so do not prefer on it — `quality` is the ordering signal. It " \
                    "only moves when WE change something, so it cannot tell you a provider " \
                    "silently upgraded a model behind an unchanged id; `generated_at` on each " \
                    "result is what survives that, being a fact about the picture rather than " \
                    "a claim about the config. Nothing here asks you to discard or regenerate.",
        }.to_json)
      end

      def self.handle_shoot(transports : Hash(String, Transport), data : JSON::Any) : JSON::Any
        prompt = data["prompt"]?.try(&.as_s?) || raise "shoot requires 'prompt'"
        id = data["camera"]?.try(&.as_s?) || "klein"
        cam = Cameras.find(id) || raise "unknown camera #{id.inspect} — call `cameras` for the list"

        # Staging, if asked for. Kept OUT of the prompt unless given: an over-specified
        # prompt drifts the concept, and these phrases are instructions the model will try
        # to obey even when the caller did not care.
        view = data["view"]?.try { |v| Direction.from_json_any(v) }
        light = data["light"]?.try { |v| Direction.from_json_any(v) }
        roll = data["view_roll"]?.try(&.as_f?) || 0.0
        staging = [] of String
        staging << ViewWords.camera(view, roll) if view
        staging << ViewWords.camera(Direction.new(0.0, 0.0, 1.0), roll) if !view && roll.abs >= 0.1
        staging << ViewWords.light(light) if light
        prompt = staging.empty? ? prompt : "#{prompt.rstrip('.')}. #{staging.join(". ")}."

        tx = transports[cam.provider]? ||
             raise "camera #{cam.id} needs the #{cam.provider.inspect} transport, which is " \
                   "not configured on this host"

        ref = reference_bytes(data)
        if ref && Cameras::REFERENCE_BLIND.includes?(cam.model)
          raise "#{cam.label} silently discards reference images — it would bill you for a " \
                "picture that ignores the subject. Choose another camera."
        end

        w, h = cam.snap(
          data["width"]?.try(&.as_i?) || 1024,
          data["height"]?.try(&.as_i?) || 1024)

        # Runware accepts JPG, JPEG, PNG and WEBP (its own default is JPG). We default to
        # webp: far smaller than png, and it does not ring along hard black outlines the
        # way jpg does — which is most of what comic art is made of.
        #
        # What comes back is LOSSY webp with NO alpha: inspecting the bytes shows a `VP8 `
        # chunk (not `VP8L`) and no `VP8X` extended chunk, at 0.11 bytes/pixel. That is
        # the right trade for serve-and-display, which is what this service is for, but it
        # rules webp out as a pipeline intermediate: the prop machine keys against a solid
        # background, and lossy chroma smears exactly the edge the key decides on. Ask for
        # png anywhere alpha or a later key is involved.
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
          # An empty reference list means "no reference"; each transport decides what
          # that requires of it, since the providers differ on whether text-to-image
          # exists at all.
          refs = ref ? [ref] of Bytes : [] of Bytes
          result = tx.edit(refs, prompt, w, h, cam.model, extra, wire_fmt.upcase)
        rescue ex
          msg = ex.message || "unknown"
          if overloaded?(msg)
            # Unbilled, and already retried with backoff inside the client.
            return JSON::Any.new({
              "status"  => JSON::Any.new("overloaded"),
              "camera"  => JSON::Any.new(cam.id),
              "pool"    => JSON::Any.new(cam.provider),
              "model"   => JSON::Any.new(cam.model),
              "version" => JSON::Any.new(cam.version.to_i64),
              "usd"     => JSON::Any.new(0.0),
              "reason"  => JSON::Any.new(msg[0, 400]),
              "retry"   => JSON::Any.new(true),
              "note"    => JSON::Any.new(
                "Runware's queue was over capacity. Not billed, and already retried with " \
                "exponential backoff before you saw this. Transient: wait and try again. " \
                "Unlike a refusal, the prompt is fine — do not reword it. Latency here is " \
                "variable by a factor of ~25 even at low concurrency, so a caller with a " \
                "deadline should set its own budget rather than assume the typical case."),
            } of String => JSON::Any)
          end
          raise ex unless refusal?(msg)
          # Unbilled. Report it as an outcome, not a failure, and never fall back to
          # another camera — a silent substitution would corrupt the caller's logs.
          return JSON::Any.new({
            "status"     => JSON::Any.new("refused"),
            "camera"     => JSON::Any.new(cam.id),
            "pool"       => JSON::Any.new(cam.provider),
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
        # Providers do not agree on what they return: Google ignores the format request
        # entirely and always sends JPEG. Re-encode rather than relabel, so moving load
        # between pools changes the queue and nothing else — a caller storing by extension
        # would otherwise write a .webp file holding a JPEG.
        img = Convert.ensure(img, wire_fmt) unless fmt == "xcf"
        img = Xcf.convert(img) if fmt == "xcf"
        # Report the format of the BYTES, not of the request.
        actual_fmt = fmt == "xcf" ? "xcf" : ImageSniff.extension(img)
        res = {
          "status" => JSON::Any.new("ok"),
          "camera" => JSON::Any.new(cam.id),
          # Which capacity pool actually served this. Needed in the RESULT and not only in
          # the `cameras` listing: a caller analysing a log of ten thousand generations
          # should not have to join back to a listing to learn which queue it was in, and
          # that is exactly the analysis that tells it where to send load next.
          "pool" => JSON::Any.new(cam.provider),
          # When the picture was actually drawn. Unlike `version` this needs no discipline
          # from us and cannot go stale: it is the only field that reflects a provider
          # changing a model behind an unchanged id. UTC, RFC 3339.
          "generated_at" => JSON::Any.new(Time.utc.to_rfc3339),
          "version"      => JSON::Any.new(cam.version.to_i64),
          "model"        => JSON::Any.new(cam.model),
          "width"        => JSON::Any.new(w.to_i64),
          "height"       => JSON::Any.new(h.to_i64),
          "bytes"        => JSON::Any.new(img.size.to_i64),
          "format"       => JSON::Any.new(fmt),
          # What the provider actually billed. nil means it reported no price, which is
          # recorded as unpriced — never silently as the camera's average, which would put
          # a guess into the caller's ledger as if it were fact.
          "usd" => result.cost ? JSON::Any.new(result.cost) : JSON::Any.new(nil),
          # true when the figure was computed rather than billed — either because the
          # provider reported no price at all (we fall back to the registry average) or
          # because the transport derived it from tokens and a published rate.
          "usd_estimated" => JSON::Any.new(result.cost.nil? || result.cost_estimated),
        } of String => JSON::Any
        res["usd"] = JSON::Any.new(cam.cost) unless result.cost
        if seed = data["seed"]?.try(&.as_i64?)
          res["seed"] = JSON::Any.new(seed)
        end
        # Echo the staging back, so whoever files the image has the fields without
        # re-deriving them — and `staging_prompt` so a human can see what the model was
        # actually told, which is the only way to judge how far it drifted.
        if v = view
          res["view"] = JSON::Any.new(v.to_json_object)
          res["view_readable"] = JSON::Any.new({
            "side"  => JSON::Any.new(v.side),
            "yaw"   => JSON::Any.new(v.yaw),
            "pitch" => JSON::Any.new(v.pitch),
          } of String => JSON::Any)
        end
        res["view_roll"] = JSON::Any.new(roll) unless roll == 0.0
        if l = light
          res["light"] = JSON::Any.new(l.to_json_object)
        end
        unless staging.empty?
          res["staging_prompt"] = JSON::Any.new(staging.join(". "))
          res["staging_note"] = JSON::Any.new(
            "AS ASKED, not measured: these models take a prompt, not a camera matrix, so " \
            "compliance is good but inexact. Do not treat the echoed vectors as ground " \
            "truth for compositing.")
        end

        if path = data["output_path"]?.try(&.as_s?)
          File.write(path, img)
          res["output_path"] = JSON::Any.new(path)
        else
          res["image_base64"] = JSON::Any.new(Base64.strict_encode(img))
          res["content_type"] = JSON::Any.new(
            case actual_fmt
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
    end
  end
end
