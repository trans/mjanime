module MJ
  module Arcana
    # How many requests this service will have in flight with one provider at a time.
    #
    # arcana-core 0.17.1 runs each request in its own fiber with a per-Toolset cap, which
    # fixed the serial bottleneck. But a Toolset-wide cap is the wrong shape for this
    # service: a single number would be shared across three independent provider pools, so
    # four shots at Runware would crowd out shots that could have gone to Google. The whole
    # value of separate pools is that they do not contend, and a global cap reintroduces the
    # contention it was meant to remove. Overlore asked for this directly.
    #
    # So the Toolset cap stays generous — a backstop against runaway fibers — and the real
    # limiting happens per pool, here.
    #
    # The numbers: Runware publishes guidance of 2-4 concurrent and runs a shared queue, so
    # 4. OpenAI and Google both state per-account ceilings that rise with spend, and neither
    # resembles a shared best-effort queue, so 6 each. These are politeness and blast-radius
    # limits rather than measured optima — the measurements showed Runware's stalls were NOT
    # caused by our concurrency — so they are deliberately conservative and overridable.
    class PoolLimit
      DEFAULTS = {
        "runware" => 4,
        "openai"  => 6,
        "google"  => 6,
      }
      FALLBACK = 4

      def self.for(pool : String) : Int32
        if v = ENV["MJ_POOL_LIMIT_#{pool.upcase}"]?.try(&.to_i?)
          return v
        end
        DEFAULTS[pool]? || FALLBACK
      end

      # A buffered channel used as a token bucket: `limit` tokens in, one taken for the
      # duration of each request. Crystal's Channel is fiber-aware, so a fiber that cannot
      # get a token parks instead of spinning, and the WebSocket read loop keeps running.
      def initialize(@limit : Int32)
        @tokens = Channel(Nil).new(@limit)
        @limit.times { @tokens.send(nil) }
        @waiting = 0
        @in_flight = 0
      end

      getter limit : Int32
      getter waiting : Int32
      getter in_flight : Int32

      def acquire(&)
        @waiting += 1
        @tokens.receive
        @waiting -= 1
        @in_flight += 1
        begin
          yield
        ensure
          @in_flight -= 1
          @tokens.send(nil)
        end
      end
    end

    # One limiter per pool, built once. A pool with no limiter configured is unlimited
    # rather than blocked — a missing entry should not silently stop a camera working.
    module PoolLimits
      @@limits = {} of String => PoolLimit

      def self.[](pool : String) : PoolLimit
        @@limits[pool] ||= PoolLimit.new(PoolLimit.for(pool))
      end

      def self.snapshot : Hash(String, Hash(String, Int32))
        @@limits.transform_values do |l|
          {"limit" => l.limit, "in_flight" => l.in_flight, "waiting" => l.waiting}
        end
      end
    end
  end
end
