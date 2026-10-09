require "../transport"
require "../../api/retry"
require "http/client"
require "http/formdata"
require "json"
require "base64"
require "uri"

module MJ
  module Arcana
    # OpenAI's image API, direct — a genuinely independent capacity pool.
    #
    # The point is throughput, not quality or price. `gpt-image-2.5-flare` and
    # `-sunburst` are the SAME models Runware fronts as `openai:gpt-image@2.5-*`, so a
    # picture drawn here is the picture you would have got anyway. What differs is the
    # door: these requests are admitted against our own OpenAI account quota instead of
    # queueing behind every other Runware customer. A congestion episode on one cannot
    # stall the other, which is the property `cameras`'s `pools` now reports and the
    # reason this file exists.
    #
    # Size rules were probed against the live API, not read off a page:
    #
    #   gpt-image-2.5-*  width and height divisible by 16; longest edge <= 3840; and a
    #                    minimum TOTAL pixel budget rather than a per-side floor (16x16 is
    #                    rejected as "below the current minimum pixel budget").
    #   gpt-image-1.5    exactly 1024x1024, 1024x1536, 1536x1024, auto.
    #
    # Both agree with what the Runware-side probing found, which is a good sign that the
    # registry's geometry is a property of the model rather than of the aggregator.
    #
    # Note the probe technique differs from Runware's: OpenAI validates the PROMPT FIRST,
    # so the empty-prompt trick that makes Runware answer size questions for free does not
    # work here. Use a real prompt with a size you expect to be refused — a 400 is unbilled,
    # but a size that happens to be VALID will generate and charge you.
    class OpenAIDirectTransport < Transport
      ENDPOINT = "https://api.openai.com/v1"

      # Mirrors the Runware client's policy, because every transport owes the service its
      # own resilience: Crystal's HTTP::Client has no default timeouts, so a transport
      # without them can hang a caller indefinitely.

      # Left to itself this API returns LOSSLESS webp (a VP8L chunk, ~0.9 bytes/pixel),
      # where Runware returns lossy VP8 at ~0.11. Same request, 8x the bytes — which would
      # ambush anyone treating the two pools as interchangeable, since the whole point of
      # the second pool is that you can move load onto it without anything else changing.
      # `output_compression` brings it into line. 80 is the default rather than 100 because
      # comparable panel sizes across pools matter more here than the last few percent of
      # fidelity; pass output_compression in `extra` to override, or 100 for lossless.
      DEFAULT_COMPRESSION = 80

      def initialize(@api_key : String,
                     @retries : Int32 = 2,
                     @read_timeout : Float64 = 180.0,
                     @compression : Int32 = DEFAULT_COMPRESSION)
      end

      def name : String
        "openai"
      end

      def edit(references : Array(Bytes), prompt : String,
               width : Int32, height : Int32, model : String,
               extra : Hash(String, JSON::Any)?,
               format : String) : GenerationResult
        size = "#{width}x#{height}"
        fmt = format.downcase
        fmt = "jpeg" if fmt == "jpg"
        STDERR.puts "[openai] #{references.empty? ? "Generate" : "Edit(refs=#{references.size})"}: " \
                    "model=#{model} #{size} #{fmt}"

        response =
          if references.empty?
            # Unlike Runware, this API has a real text-to-image route, so an unreferenced
            # shot is not forced through a flat canvas.
            generate(prompt, size, model, fmt, extra)
          else
            edit_with_references(references, prompt, size, model, fmt, extra)
          end

        unless response.status_code == 200
          raise "OpenAI image error (#{response.status_code}): #{response.body}"
        end

        body = JSON.parse(response.body)
        b64 = body["data"]?.try(&.as_a?.try(&.first?)).try(&.["b64_json"]?).try(&.as_s?)
        raise "OpenAI returned no image data: #{response.body[0, 300]}" unless b64

        # No price in the response — the images API reports token `usage`, not dollars. nil
        # is the honest answer and makes the service fall back to the registry average with
        # usd_estimated:true. Converting tokens to dollars here would need a rate I would
        # have to invent, and an invented rate in a caller's ledger reads as fact.
        GenerationResult.new(
          image_data: Base64.decode(b64),
          response_id: body["created"]?.try(&.to_s),
          cost: nil,
        )
      end

      private def generate(prompt : String, size : String, model : String,
                           fmt : String, extra : Hash(String, JSON::Any)?)
        payload = {
          "model"         => JSON::Any.new(model),
          "prompt"        => JSON::Any.new(prompt),
          "size"          => JSON::Any.new(size),
          "output_format" => JSON::Any.new(fmt),
        } of String => JSON::Any
        if compressible?(fmt) && !(extra.try(&.has_key?("output_compression")))
          payload["output_compression"] = JSON::Any.new(@compression.to_i64)
        end
        merge_known(payload, extra)
        post_json("/images/generations", payload.to_json)
      end

      private def edit_with_references(references : Array(Bytes), prompt : String,
                                       size : String, model : String, fmt : String,
                                       extra : Hash(String, JSON::Any)?)
        with_retries("POST /images/edits") do
          io = IO::Memory.new
          builder = HTTP::FormData::Builder.new(io)
          builder.field("model", model)
          builder.field("prompt", prompt)
          builder.field("size", size)
          builder.field("output_format", fmt)
          # Preserving the reference subject is the whole job here.
          builder.field("input_fidelity", "high")
          if compressible?(fmt) && !(extra.try(&.has_key?("output_compression")))
            builder.field("output_compression", @compression.to_s)
          end
          if e = extra
            KNOWN_EXTRA.each do |k|
              if v = e[k]?
                builder.field(k, v.to_s.strip('"'))
              end
            end
          end
          references.each_with_index do |bytes, i|
            ext, mime = sniff(bytes)
            builder.file("image[]", IO::Memory.new(bytes),
              HTTP::FormData::FileMetadata.new(filename: "ref#{i}.#{ext}"),
              HTTP::Headers{"Content-Type" => mime})
          end
          builder.finish

          client = new_client
          begin
            client.post("/v1/images/edits",
              headers: HTTP::Headers{
                "Authorization" => "Bearer #{@api_key}",
                "Content-Type"  => builder.content_type,
              },
              body: io.to_s)
          ensure
            client.close
          end
        end
      end

      private def post_json(path : String, body : String)
        with_retries("POST #{path}") do
          client = new_client
          begin
            client.post("/v1#{path}",
              headers: HTTP::Headers{
                "Authorization" => "Bearer #{@api_key}",
                "Content-Type"  => "application/json",
              },
              body: body)
          ensure
            client.close
          end
        end
      end

      # Only pass through parameters this API actually defines. OpenAI rejects unknown
      # fields outright — which is friendlier than Runware, where an unknown parameter is
      # accepted silently and a 200 proves nothing about whether it engaged.
      KNOWN_EXTRA = ["quality", "background", "output_compression", "input_fidelity"]

      private def merge_known(payload : Hash(String, JSON::Any),
                              extra : Hash(String, JSON::Any)?) : Nil
        return unless e = extra
        KNOWN_EXTRA.each do |k|
          if v = e[k]?
            payload[k] = v
          end
        end
      end

      private def compressible?(fmt : String) : Bool
        fmt == "webp" || fmt == "jpeg"
      end

      private def new_client : HTTP::Client
        client = HTTP::Client.new(URI.parse(ENDPOINT))
        client.connect_timeout = 15.seconds
        client.read_timeout = @read_timeout.seconds
        client.write_timeout = 60.seconds
        client
      end

      private def with_retries(what : String, & : -> HTTP::Client::Response) : HTTP::Client::Response
        attempt = 0
        loop do
          begin
            response = yield
            # OpenAI returns 429 both for rate limiting and for `insufficient_quota`, which
            # means the account is out of credit. Retrying the latter is pure latency for a
            # guaranteed failure, so the body decides, not the status.
            return response unless MJ::Retry.retryable?(response.status_code, response.body)
            return response if attempt >= @retries
            delay = MJ::Retry.delay(attempt + 1, response)
            STDERR.puts "[openai] #{what} got #{response.status_code}, retrying in #{delay.total_seconds.round(1)}s (#{attempt + 1}/#{@retries})"
            attempt += 1
            sleep delay
          rescue ex : IO::TimeoutError | IO::Error | Socket::Error
            raise ex if attempt >= @retries
            delay = MJ::Retry.backoff(attempt + 1)
            STDERR.puts "[openai] #{what} #{ex.class}: #{ex.message}, retrying in #{delay.total_seconds.round(1)}s (#{attempt + 1}/#{@retries})"
            attempt += 1
            sleep delay
          end
        end
      end

      # truthful content type per part.
      private def sniff(bytes : Bytes) : {String, String}
        return {"png", "image/png"} if bytes.size > 8 && bytes[1] == 0x50 && bytes[2] == 0x4E
        return {"jpg", "image/jpeg"} if bytes.size > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8
        if bytes.size > 12 && String.new(bytes[0, 4]) == "RIFF" && String.new(bytes[8, 4]) == "WEBP"
          return {"webp", "image/webp"}
        end
        {"png", "image/png"}
      end
    end
  end
end
