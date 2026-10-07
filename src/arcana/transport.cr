require "json"

module MJ
  module Arcana
    # Where a camera's request actually goes.
    #
    # This exists because of a mistake worth not repeating. mj:camera offers seven cameras
    # across four model families — Runware's own FLUX, Google, OpenAI, BFL — and I described
    # them to a caller as independent backends, so a congestion episode on one "need not
    # touch" another. That is false. Every one of them posts to a single endpoint,
    # `api.runware.ai/v1`, on a single account: the model ids are strings in the request
    # body. The models run on different infrastructure; ADMISSION CONTROL does not. Under a
    # spike all seven cameras queue behind the same door.
    #
    # Model diversity is not capacity diversity, and the registry was hiding the difference
    # because every Camera happened to share a client. A camera now names its transport, so
    # the distinction is visible in the type rather than implied.
    #
    # The useful property of a real second transport is not more throughput, it is a
    # PUBLISHED ceiling. Runware runs a shared best-effort queue and publishes no limit, so
    # there is no headroom to buy when it stalls — measured p50 11.4s, p90 21.6s, tail 142s,
    # with episodes that come and go independently of our own concurrency. Google's direct
    # API, by contrast, states a spend ceiling on a rolling 10-minute window (tier 3 = $200,
    # roughly 4.8 nano images/second) that rises with spend; OpenAI publishes per-account
    # images-per-minute. A number you can plan against and raise is worth more than a
    # cheaper average you cannot.
    #
    # ## Adding a provider
    #
    # Implement `edit` and register the transport under a name, then give the new cameras
    # `provider:` that name. Everything the callers depend on is unchanged — `shoot` keeps
    # its request shape and its result contract, snapping still happens from the camera's
    # own `dims`/`range`, and the refused/overloaded classification still applies. What a
    # new transport owes the service:
    #
    #   - honest `cost` on the result, or nil. Never a guess: `usd_estimated` is only
    #     trustworthy because nil means "the provider said nothing", not "about this much".
    #   - errors raised with the provider's own message intact, so `refusal?` and
    #     `overloaded?` can classify them. Both match on provider wording rather than
    #     status codes, because OpenAI reuses one code for a refusal and a bad parameter.
    #   - its own retry/backoff and timeouts. Crystal's HTTP::Client has no default
    #     timeouts, so a transport without them can hang a caller forever.
    #
    # Measure cost and latency from live calls before adding the camera. Do not quote the
    # price list — docs/techniques.md has the probe procedure, and this service's numbers
    # are all measured.
    abstract class Transport
      # A short stable name a Camera refers to, e.g. "runware".
      abstract def name : String

      # Draw a picture. `references` may be empty where a transport supports text-to-image
      # directly; the Runware transport has no text2img route and substitutes a flat canvas.
      abstract def edit(references : Array(Bytes), prompt : String,
                        width : Int32, height : Int32, model : String,
                        extra : Hash(String, JSON::Any)?,
                        format : String) : GenerationResult
    end

    # The only transport today. Wraps the existing client rather than changing it, so the
    # engines that share that client (prop, pixelize, base, decorate) are untouched.
    class RunwareTransport < Transport
      def initialize(@client : RunwareClient)
      end

      def name : String
        "runware"
      end

      def edit(references : Array(Bytes), prompt : String,
               width : Int32, height : Int32, model : String,
               extra : Hash(String, JSON::Any)?,
               format : String) : GenerationResult
        @client.edit_references(references, prompt, width, height, model, extra, format)
      end
    end
  end
end
