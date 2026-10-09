require "../transport"
require "../../api/retry"
require "../../api/image_sniff"
require "http/client"
require "json"
require "base64"
require "uri"

module MJ
  module Arcana
    # Google's Gemini image API, direct — a third independent capacity pool.
    #
    # Same models Runware fronts as `google:4@3` and `google:nano-banana@2-lite`, admitted
    # against our own Google quota instead of queueing behind every other Runware customer.
    # Unlike the OpenAI pool this one is also markedly FASTER: lite measured ~2.8s direct
    # against 6.1s through Runware, which makes it the best candidate for anything a player
    # might notice.
    #
    # Everything below was probed against the live API, and three things differ from every
    # other provider here:
    #
    # 1. **It takes an aspect RATIO, not pixel dimensions.** The 14 legal ratios and the
    #    size each produces are in `Cameras::GOOGLE_DIMS` / `RATIO_FOR`, measured one call
    #    at a time. Eight of them match the Nano sizes probed through Runware exactly, which
    #    is good evidence the size set belongs to the model rather than the aggregator — and
    #    two (928x1152, 1152x928) are sizes Runware does not expose at all.
    # 2. **It rejects unknown fields.** Runware silently swallows a parameter it does not
    #    implement, so a 200 there proves nothing; OpenAI accepts the field name but the
    #    model may still refuse it. Google answers `Unknown name "bogusField"`. A 200 from
    #    this provider actually means the parameters engaged, which makes it the only one of
    #    the three whose success is self-verifying.
    # 3. **It reports tokens, so cost is computed rather than quoted.** `usageMetadata`
    #    gives image output tokens — a flat 1120 for every 1K image regardless of aspect, so
    #    a 2928x352 panorama costs exactly what a square does.
    class GoogleDirectTransport < Transport
      ENDPOINT = "https://generativelanguage.googleapis.com"

      # Published USD per 1M image output tokens, by model. Measured token counts times
      # these give the per-call figure. NOT billed-back numbers — Google reports tokens and
      # no price — so results carry usd_estimated: true.
      #
      # The batch endpoint (batchGenerateContent, which every image model supports) is half
      # these rates. Nothing uses it yet; it is the right home for a stock library, where
      # no caller is waiting.
      USD_PER_MTOK = {
        "gemini-3.1-flash-image"      => 60.0,
        "gemini-3.1-flash-lite-image" => 30.0,
        "gemini-3-pro-image"          => 60.0,
      }

      # Reverse of the measured size table: which ratio string produces this exact size.
      # The service snaps a caller's request to one of these sizes through the camera's
      # `dims`, so the lookup is always an exact hit.
      RATIO_FOR = {
        {1024, 1024} => "1:1",
        {512, 2064}  => "1:4",
        {352, 2928}  => "1:8",
        {848, 1264}  => "2:3",
        {1264, 848}  => "3:2",
        {896, 1200}  => "3:4",
        {2064, 512}  => "4:1",
        {1200, 896}  => "4:3",
        {928, 1152}  => "4:5",
        {1152, 928}  => "5:4",
        {2928, 352}  => "8:1",
        {768, 1376}  => "9:16",
        {1376, 768}  => "16:9",
        {1584, 672}  => "21:9",
      }

      def initialize(@api_key : String,
                     @retries : Int32 = 2,
                     @read_timeout : Float64 = 180.0)
      end

      def name : String
        "google"
      end

      def edit(references : Array(Bytes), prompt : String,
               width : Int32, height : Int32, model : String,
               extra : Hash(String, JSON::Any)?,
               format : String) : GenerationResult
        ratio = RATIO_FOR[{width, height}]? ||
                raise "#{width}x#{height} is not one of Gemini's aspect ratios — the camera's " \
                      "dims should have snapped it to one of #{RATIO_FOR.size} sizes"
        STDERR.puts "[google] #{references.empty? ? "Generate" : "Edit(refs=#{references.size})"}: " \
                    "model=#{model} #{width}x#{height} (#{ratio})"

        parts = [] of JSON::Any
        parts << JSON::Any.new({"text" => JSON::Any.new(prompt)} of String => JSON::Any)
        references.each do |bytes|
          parts << JSON::Any.new({
            "inlineData" => JSON::Any.new({
              "mimeType" => JSON::Any.new(ImageSniff.mime(bytes)),
              "data"     => JSON::Any.new(Base64.strict_encode(bytes)),
            } of String => JSON::Any),
          } of String => JSON::Any)
        end

        gen_config = {
          "responseModalities" => JSON::Any.new([JSON::Any.new("IMAGE")]),
          "imageConfig"        => JSON::Any.new({"aspectRatio" => JSON::Any.new(ratio)} of String => JSON::Any),
        } of String => JSON::Any

        body = {
          "contents"         => JSON::Any.new([JSON::Any.new({"parts" => JSON::Any.new(parts)} of String => JSON::Any)]),
          "generationConfig" => JSON::Any.new(gen_config),
        }.to_json

        response = post("/v1beta/models/#{model}:generateContent", body)
        unless response.status_code == 200
          raise "Google image error (#{response.status_code}): #{response.body}"
        end

        parsed = JSON.parse(response.body)
        image = extract_image(parsed)
        raise "Google returned no image data: #{response.body[0, 300]}" unless image

        GenerationResult.new(
          image_data: image,
          response_id: parsed["responseId"]?.try(&.as_s?),
          cost: cost_of(parsed, model),
          # Computed from tokens times a published rate, never billed back by Google.
          cost_estimated: true,
        )
      end

      # The response interleaves text and image parts; take the first image.
      private def extract_image(parsed : JSON::Any) : Bytes?
        parsed["candidates"]?.try(&.as_a?).try &.each do |cand|
          cand["content"]?.try(&.["parts"]?).try(&.as_a?).try &.each do |part|
            if data = part["inlineData"]?.try(&.["data"]?).try(&.as_s?)
              return Base64.decode(data)
            end
          end
        end
        nil
      end

      # Image output tokens times the published rate. Text and "thinking" tokens are billed
      # separately at the text rate and are not counted here: measured at ~445 against 1120
      # image tokens, so under a tenth of a cent against ~6.7 cents. Said plainly rather
      # than folded in silently, because a figure that quietly omits part of the bill is
      # the kind of thing that reads as fact in someone else's ledger.
      private def cost_of(parsed : JSON::Any, model : String) : Float64?
        rate = USD_PER_MTOK[model]?
        return nil unless rate
        details = parsed["usageMetadata"]?.try(&.["candidatesTokensDetails"]?).try(&.as_a?)
        return nil unless details
        details.each do |d|
          if d["modality"]?.try(&.as_s?) == "IMAGE"
            if toks = d["tokenCount"]?.try(&.as_i?)
              return toks * rate / 1_000_000.0
            end
          end
        end
        nil
      end

      private def post(path : String, body : String) : HTTP::Client::Response
        attempt = 0
        loop do
          begin
            response = send(path, body)
            return response unless MJ::Retry.retryable?(response.status_code, response.body)
            return response if attempt >= @retries
            delay = MJ::Retry.delay?(attempt + 1, response)
            unless delay
              asked = MJ::Retry.requested_delay(response)
              STDERR.puts "[google] #{path} got #{response.status_code}, provider asked for #{asked.try(&.round) || "?"}s — not retrying"
              return response
            end
            STDERR.puts "[google] #{path} got #{response.status_code}, retrying in #{delay.total_seconds.round(1)}s (#{attempt + 1}/#{@retries})"
            attempt += 1
            sleep delay
          rescue ex : IO::TimeoutError | IO::Error | Socket::Error
            raise ex if attempt >= @retries
            delay = MJ::Retry.backoff(attempt + 1)
            STDERR.puts "[google] #{path} #{ex.class}: #{ex.message}, retrying in #{delay.total_seconds.round(1)}s (#{attempt + 1}/#{@retries})"
            attempt += 1
            sleep delay
          end
        end
      end

      private def send(path : String, body : String) : HTTP::Client::Response
        client = HTTP::Client.new(URI.parse(ENDPOINT))
        client.connect_timeout = 15.seconds
        client.read_timeout = @read_timeout.seconds
        client.write_timeout = 60.seconds
        begin
          # The key goes in the query string, so it must never be logged with the path.
          client.post("#{path}?key=#{@api_key}",
            headers: HTTP::Headers{"Content-Type" => "application/json"},
            body: body)
        ensure
          client.close
        end
      end
    end
  end
end
