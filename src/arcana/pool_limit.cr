module MJ
  module Arcana
    # How many requests this service will have in flight with one provider at a time.
    #
    # These numbers are the configuration; **arcana-core's lanes do the enforcing**
    # (`ts.lane(pool, max_concurrent:)` in CameraService.register). This file used to hold
    # a token bucket acquired inside the handler, and that was subtly wrong: parking on a
    # pool from inside the handler still occupies one of the toolset's slots, so a Runware
    # backlog could starve Google of slots while Google had capacity — reintroducing the
    # cross-pool contention that separate pools exist to remove. A lane is waited for
    # BEFORE the request takes a slot, which is the ordering that actually works.
    #
    # The numbers: Runware publishes guidance of 2-4 concurrent and runs a shared queue, so
    # 4. OpenAI and Google both state per-account ceilings that rise with spend and neither
    # resembles a shared best-effort queue, so 6 each. These are politeness and
    # blast-radius limits rather than measured optima — the measurements showed Runware's
    # stalls were NOT caused by our concurrency — so they are deliberately conservative and
    # overridable per pool with MJ_POOL_LIMIT_<POOL>.
    module PoolLimit
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
    end
  end
end
