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
      getter cost : Float64          # USD per image, measured
      getter seconds : Float64       # typical wall-clock, measured
      getter dims : Array(Array(Int32))
      getter note : String
      @[JSON::Field(ignore: true)]
      getter extra : Hash(String, JSON::Any)

      def initialize(@id, @label, @model, @cost, @seconds, @dims, @note,
                     @extra = {} of String => JSON::Any)
      end

      # Nearest supported size by ASPECT, then by area. Models reject sizes outright
      # rather than snapping, so this has to happen before the request goes out.
      def snap(width : Int32, height : Int32) : {Int32, Int32}
        want = width.to_f / height
        best = dims.min_by do |wh|
          w, h = wh[0], wh[1]
          ratio_err = (w.to_f / h - want).abs
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

      # Models that took arbitrary-ish sizes in testing; 896x1200 and 1024x1024 both worked.
      OPEN_DIMS = [[1024, 1024], [896, 1200], [1200, 896], [768, 1024], [1024, 768]]

      def self.steps(n : Int32, cfg : Float64) : Hash(String, JSON::Any)
        {"steps" => JSON::Any.new(n.to_i64), "CFGScale" => JSON::Any.new(cfg)}
      end

      ALL = [
        Camera.new(
          id: "klein", label: "FLUX.2 Klein 9B", model: "runware:400@2",
          cost: 0.0059, seconds: 9.6, dims: OPEN_DIMS,
          note: "The little camera that could. Unremarkable but dependable; cheapest that " \
                "holds a character.",
          extra: steps(20, 3.5)),
        Camera.new(
          id: "flare", label: "GPT-Image 2.5 Flare", model: "openai:gpt-image@2.5-flare",
          cost: 0.0148, seconds: 17.0, dims: OPEN_DIMS,
          note: "Ambitious staging, livelier compositions, but more prone to anatomy " \
                "mistakes. Shares failure modes with Sunburst — not an independent fallback."),
        Camera.new(
          id: "sunburst", label: "GPT-Image 2.5 Sunburst", model: "openai:gpt-image@2.5-sunburst",
          cost: 0.0139, seconds: 20.0, dims: OPEN_DIMS,
          note: "Flare's sibling. Fails on the same prompts Flare does."),
        Camera.new(
          id: "lite", label: "Nano Banana 2 Lite", model: "google:nano-banana@2-lite",
          cost: 0.0340, seconds: 6.1, dims: NANO_DIMS,
          note: "The fastest thing measured. Imposes its own house style and is nearly " \
                "indifferent to how good the reference is."),
        Camera.new(
          id: "nano", label: "Nano Banana 2", model: "google:4@3",
          cost: 0.0692, seconds: 12.5, dims: NANO_DIMS,
          note: "Richest colour and staging. Google's content filter is strict AND " \
                "probabilistic — identical prompts pass and fail minutes apart. Refusals " \
                "are not billed, so retry is free but costs latency."),
        Camera.new(
          id: "hero", label: "GPT Image 1.5", model: "openai:4@1",
          cost: 0.1362, seconds: 20.0, dims: OPEN_DIMS,
          note: "Premium. Twice Nano's price — for the shot that matters, not for every " \
                "panel."),
        Camera.new(
          id: "kontext", label: "FLUX Kontext dev", model: "bfl:3@1",
          cost: 0.0400, seconds: 8.7, dims: KONTEXT_DIMS,
          note: "Conservative to a fault: preserves the reference faithfully but barely " \
                "restyles. Poor at transformation, good at leaving things alone."),
      ]

      BY_ID = ALL.to_h { |c| {c.id, c} }

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
