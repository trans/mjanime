require "json"

module MJ
  module Arcana
    # The camera registry — what a caller should NOT have to know.
    #
    # Every image model on Runware arrives with its own geometry rules, its own parameter
    # spelling, and its own ways of failing quietly. Callers that talk to the API directly
    # reimplement that knowledge and get some of it wrong; arcana-ai's identity methods sat
    # broken in production for months because nothing surfaced the mistake. Encoding it once,
    # here, is the whole reason this service exists.
    #
    # Costs and timings below are MEASURED from live calls (Runware's `includeCost`), not
    # quoted from documentation. Re-measure rather than trusting them to stay true.
    struct Camera
      include JSON::Serializable

      getter id : String
      getter label : String
      getter model : String
      getter cost : Float64    # USD per image, measured
      getter seconds : Float64 # typical wall-clock, measured
      # Bump when anything that changes a camera's OUTPUT changes — the model id, the
      # default parameters, the prompt scaffolding. Callers key caches on it, so a bump
      # is how they learn this camera's old pictures are no longer what it would produce.
      getter version : Int32
      # A rank, not a measurement: ordered by Trans's eye over the model survey, ascending.
      # Reuse can prefer a higher rank when several cached pictures match.
      getter quality : Int32
      # Models constrain size in one of two ways, and conflating them loses real sizes.
      # `dims` is an exhaustive list (Nano, Kontext, GPT Image 1.5); `range` is
      # {min, max, step} and accepts anything in between (Klein, GPT-Image 2.5). Exactly
      # one is set. Both were read off the API's own rejection messages, not guessed —
      # an empty positivePrompt makes size validation answer for free, because it runs
      # before prompt validation.
      getter dims : Array(Array(Int32))?
      getter range : Tuple(Int32, Int32, Int32)?
      getter note : String
      # Which transport serves this camera. All seven are "runware" today, and that is the
      # point of recording it: every one of them queues behind a single endpoint on a single
      # account, so choosing a different camera does NOT route around congestion. Model
      # diversity is not capacity diversity. When a second transport exists, this field is
      # what tells a caller which cameras are genuinely independent pools.
      getter provider : String
      @[JSON::Field(ignore: true)]
      getter extra : Hash(String, JSON::Any)

      def initialize(@id, @label, @model, @cost, @seconds, @note,
                     @quality : Int32, @version : Int32 = 1,
                     @dims = nil, @range = nil,
                     @provider : String = "runware",
                     @extra = {} of String => JSON::Any)
        raise "camera #{@id}: set exactly one of dims or range" if @dims.nil? == @range.nil?
      end

      def sizes : Array(String)
        if d = dims
          d.map { |wh| "#{wh[0]}x#{wh[1]}" }
        elsif r = range
          ["#{r[0]}-#{r[1]} in steps of #{r[2]}"]
        else
          [] of String
        end
      end

      # Models reject unsupported sizes outright rather than snapping, so this has to
      # happen before the request goes out.
      def snap(width : Int32, height : Int32) : {Int32, Int32}
        if r = range
          snap_to_range(width, height, r)
        else
          snap_to_list(width, height, dims.not_nil!)
        end
      end

      # A range keeps the caller's aspect ratio exactly — scale to fit the bounds, then
      # round each side to the step. Treating these as a short list (which is what an
      # earlier version did) threw away every size not on it: a 16:9 request collapsed
      # to 4:3 for no reason at all.
      private def snap_to_range(width : Int32, height : Int32,
                                r : Tuple(Int32, Int32, Int32)) : {Int32, Int32}
        min, max, step = r
        w = width.to_f
        h = height.to_f
        shrink = Math.min(max / w, max / h)
        if shrink < 1.0
          w *= shrink; h *= shrink
        end
        grow = Math.max(min / w, min / h)
        if grow > 1.0
          w *= grow; h *= grow
        end
        {round_step(w, min, max, step), round_step(h, min, max, step)}
      end

      private def round_step(v : Float64, min : Int32, max : Int32, step : Int32) : Int32
        n = ((v / step).round.to_i * step)
        n.clamp(((min + step - 1) // step) * step, (max // step) * step)
      end

      # A list has no freedom, so take the nearest by ASPECT first and area only as a
      # tiebreak: a wrong aspect ruins the composition, where a wrong area just resamples.
      private def snap_to_list(width : Int32, height : Int32,
                               list : Array(Array(Int32))) : {Int32, Int32}
        want = Math.log(width.to_f / height)
        best = list.min_by do |wh|
          w, h = wh[0], wh[1]
          # log-ratio so landscape and portrait errors are measured symmetrically
          ratio_err = (Math.log(w.to_f / h) - want).abs
          area_err = ((w * h) - (width * height)).abs.to_f / (width * height)
          ratio_err * 10.0 + area_err
        end
        {best[0], best[1]}
      end
    end

    module Cameras
      # Nano Banana's fixed set. There is no 1024x768 and no 768x1024 — the two sizes a
      # comic panel most wants — so those snap to 1200x896 / 896x1200, which are within
      # 0.5% of 4:3 and slightly larger.
      NANO_DIMS = [[1024, 1024], [1376, 768], [768, 1376], [1548, 672], [1584, 672],
                   [1200, 896], [896, 1200], [1264, 848], [848, 1264]]

      # FLUX Kontext publishes a different fixed set again.
      KONTEXT_DIMS = [[1568, 672], [1392, 752], [1184, 880], [1248, 832], [1024, 1024],
                      [832, 1248], [880, 1184], [752, 1392], [672, 1568]]

      # GPT Image 1.5 publishes a very short list.
      HERO_DIMS = [[1024, 1024], [1536, 1024], [1024, 1536]]

      # Ranges, read off the API's own rejection messages: {min, max, step}.
      KLEIN_RANGE = {128, 2048, 16}
      GPT25_RANGE = {16, 3840, 16}

      def self.steps(n : Int32, cfg : Float64) : Hash(String, JSON::Any)
        {"steps" => JSON::Any.new(n.to_i64), "CFGScale" => JSON::Any.new(cfg)}
      end

      ALL = [
        Camera.new(
          id: "klein", label: "FLUX.2 Klein 9B", model: "runware:400@2",
          cost: 0.0059, seconds: 9.6, quality: 1, range: KLEIN_RANGE,
          note: "The little camera that could. Unremarkable but dependable; cheapest that " \
                "holds a character.",
          extra: steps(20, 3.5)),
        Camera.new(
          id: "flare", label: "GPT-Image 2.5 Flare", model: "openai:gpt-image@2.5-flare",
          cost: 0.0148, seconds: 17.0, quality: 2, range: GPT25_RANGE,
          note: "Ambitious staging, livelier compositions, but more prone to anatomy " \
                "mistakes. Shares failure modes with Sunburst — not an independent fallback."),
        Camera.new(
          id: "sunburst", label: "GPT-Image 2.5 Sunburst", model: "openai:gpt-image@2.5-sunburst",
          cost: 0.0139, seconds: 20.0, quality: 2, range: GPT25_RANGE,
          note: "Flare's sibling. Fails on the same prompts Flare does."),
        Camera.new(
          id: "lite", label: "Nano Banana 2 Lite", model: "google:nano-banana@2-lite",
          cost: 0.0340, seconds: 6.1, quality: 3, dims: NANO_DIMS,
          note: "The fastest thing measured. Imposes its own house style and is nearly " \
                "indifferent to how good the reference is."),
        Camera.new(
          id: "nano", label: "Nano Banana 2", model: "google:4@3",
          cost: 0.0692, seconds: 12.5, quality: 4, dims: NANO_DIMS,
          note: "Richest colour and staging. Google's content filter is strict AND " \
                "probabilistic — identical prompts pass and fail minutes apart. Refusals " \
                "are not billed, so retry is free but costs latency."),
        Camera.new(
          id: "hero", label: "GPT Image 1.5", model: "openai:4@1",
          cost: 0.1362, seconds: 20.0, quality: 5, dims: HERO_DIMS,
          note: "Premium. Twice Nano's price — for the shot that matters, not for every " \
                "panel."),
        # --- the openai pool: the SAME models, reached directly ---
        #
        # Not here for price or quality — `flare` and `dflare` are the same model and draw
        # the same picture. They are here for THROUGHPUT: these are admitted against our
        # own OpenAI quota rather than queueing behind every other Runware customer, so a
        # congestion episode on one pool cannot stall the other. `cameras`'s `pools` says
        # which ids are independent; a caller spreading load or failing over must cross
        # pools, not just cameras.
        #
        # Costs are what OpenAI charges us directly and the seconds are measured here. The
        # images API returns token `usage` but no price, so a result's `usd` falls back to
        # these with usd_estimated:true — honest, where converting tokens at a rate I made
        # up would not be.
        #
        # Latency is NOT simply the same as the Runware twin, so do not assume the pools
        # are interchangeable on speed:
        #
        #   dflare     10.6s (n=4: 12.7, 10.0, 11.2, 8.4)   vs flare    17.0s  — faster
        #   dsunburst  11.5s (n=1)                          vs sunburst 20.0s  — faster
        #   dhero      33.3s (n=2: 40.0, 26.5)              vs hero     20.0s  — SLOWER
        #
        # Small samples, and Runware's own numbers move with its queue, so treat these as
        # order-of-magnitude rather than precise. The 2.5 pair being faster direct is
        # unsurprising — one less hop and no shared queue. dhero being slower is the one
        # worth remembering if latency matters on a premium shot.
        Camera.new(
          id: "dflare", label: "GPT-Image 2.5 Flare (direct)", model: "gpt-image-2.5-flare",
          cost: 0.0148, seconds: 10.6, quality: 2, range: GPT25_RANGE, provider: "openai",
          note: "Same model as `flare`, on an independent queue. Reach for this when " \
                "Runware is congested or when you need to spread sustained load."),
        Camera.new(
          id: "dsunburst", label: "GPT-Image 2.5 Sunburst (direct)",
          model: "gpt-image-2.5-sunburst",
          cost: 0.0139, seconds: 11.5, quality: 2, range: GPT25_RANGE, provider: "openai",
          note: "Same model as `sunburst`, independent queue. Shares Flare's failure " \
                "modes, so not a fallback for `dflare` either."),
        Camera.new(
          id: "dhero", label: "GPT Image 1.5 (direct)", model: "gpt-image-1.5",
          cost: 0.1362, seconds: 33.3, quality: 5, dims: HERO_DIMS, provider: "openai",
          note: "Same model as `hero`, independent queue."),
        Camera.new(
          id: "kontext", label: "FLUX Kontext dev", model: "bfl:3@1",
          cost: 0.0400, seconds: 8.7, quality: 1, dims: KONTEXT_DIMS,
          note: "Conservative to a fault: preserves the reference faithfully but barely " \
                "restyles. Poor at transformation, good at leaving things alone."),
      ]

      BY_ID = ALL.to_h { |c| {c.id, c} }

      # Which cameras are independent capacity pools, grouped by transport. With one
      # transport this is a single group of seven, which is exactly the thing worth being
      # able to see: a spike cannot be spread across these by picking different cameras.
      def self.pools : Hash(String, Array(String))
        ALL.group_by(&.provider).transform_values(&.map(&.id))
      end

      # Models that silently DISCARD a reference image. Sending one costs money and
      # changes nothing — FLUX.1 schnell returns a byte-identical image with and without.
      # Kept here so the service can refuse rather than quietly charge for a no-op.
      REFERENCE_BLIND = Set{"runware:100@1"}

      def self.find(id : String) : Camera?
        BY_ID[id]?
      end

      def self.list : Array(Camera)
        ALL.sort_by(&.cost)
      end
    end
  end
end
