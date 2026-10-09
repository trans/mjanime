require "http/client"
require "json"

module MJ
  # When to try again, and how long to wait — in one place, because two transports need
  # identical answers and a divergence here is invisible until a launch.
  #
  # @memo found two defects in the first version of this, both real:
  #
  #   1. **The provider tells you how long to wait and we ignored it.** Runware answers a
  #      capacity rejection with `429` + `serviceOverloaded`, a `retryAfter` value in the
  #      body and a `Retry-After` header. Guessing an exponential backoff when the API has
  #      stated a number is strictly worse: too short and you add load to something already
  #      over capacity, too long and you waste a caller's deadline.
  #   2. **Not every 429 is worth retrying.** OpenAI returns 429 for rate limiting AND for
  #      `insufficient_quota`, which means the account is out of money. Waiting never fixes
  #      that, so a blanket 429 retry burns three attempts and the latency to arrive at the
  #      same failure. Same shape as the refusal-vs-error trap: the status code is not the
  #      signal, the body is.
  module Retry
    # Transient by status. 429 is included but gated by `permanent?` below.
    RETRYABLE = [408, 429, 500, 502, 503, 504]

    # Phrases that mean "this will fail again however long you wait". Collected from
    # provider responses; do not add one speculatively, because a wrong entry here turns a
    # transient blip into an immediate hard failure.
    PERMANENT_MARKERS = [
      "insufficient_quota", # OpenAI: account out of credit
      "billing_hard_limit", # OpenAI: spend cap reached
      "account_deactivated",
      "invalid_api_key",
    ]

    def self.retryable?(status : Int32, body : String) : Bool
      return false unless RETRYABLE.includes?(status)
      !permanent?(body)
    end

    def self.permanent?(body : String) : Bool
      PERMANENT_MARKERS.any? { |m| body.includes?(m) }
    end

    # How long to wait before attempt N (1-based), honouring whatever the provider said.
    #
    # Precedence: the `Retry-After` header, then a `retryAfter` field anywhere in the body,
    # then exponential backoff with jitter. Jitter matters because several fibers hitting
    # the same 429 would otherwise retry in lockstep and rebuild the burst that caused it.
    def self.delay(attempt : Int32, response : HTTP::Client::Response?) : Time::Span
      if r = response
        if secs = from_header(r) || from_body(r.body)
          # Trust it, but not unboundedly: a provider asking for ten minutes should not
          # silently park a caller that has its own deadline.
          return Math.min(secs, 60.0).seconds
        end
      end
      backoff(attempt)
    end

    def self.backoff(attempt : Int32) : Time::Span
      (Math.min(2.0 ** attempt, 32.0) + Random.rand).seconds
    end

    private def self.from_header(response : HTTP::Client::Response) : Float64?
      raw = response.headers["Retry-After"]? || response.headers["retry-after"]?
      return nil unless raw
      # RFC 7231 allows either seconds or an HTTP date.
      if secs = raw.to_f?
        return secs if secs >= 0
      end
      begin
        delta = (Time::Format::HTTP_DATE.parse(raw) - Time.utc).total_seconds
        return delta if delta > 0
      rescue
        # not a date either; fall through to backoff
      end
      nil
    end

    # Runware puts it in the error object rather than a header, so look for it by name
    # rather than assuming a shape — the body is an array of task results, and the field
    # has appeared at more than one depth.
    private def self.from_body(body : String) : Float64?
      return nil if body.empty? || body.size > 64_000
      json = begin
        JSON.parse(body)
      rescue
        return nil
      end
      find_retry_after(json)
    end

    private def self.find_retry_after(node : JSON::Any) : Float64?
      if h = node.as_h?
        h.each do |k, v|
          if k == "retryAfter" || k == "retry_after"
            return v.as_f? || v.as_i?.try(&.to_f) || v.as_s?.try(&.to_f?)
          end
          if found = find_retry_after(v)
            return found
          end
        end
      elsif a = node.as_a?
        a.each do |v|
          if found = find_retry_after(v)
            return found
          end
        end
      end
      nil
    end
  end
end
