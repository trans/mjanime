require "http/client"
require "json"
require "arcana-ai"

module MJ
  module Arcana
    # Which queue a voice request waits in, and how many of each run at once.
    #
    # A lane is one limit a provider actually enforces, not one provider. ElevenLabs
    # counts its models in families, each with its own ceiling per plan: on Starter, 3 at
    # once for v3 and v2, and 6 for Flash and Turbo. Measured 2026-10-21: with three v3
    # lines running, a fourth was refused (429 `concurrent_limit_exceeded`), while a Flash
    # line went straight through, its `current-concurrent-requests` header counting only
    # itself against a maximum of 6. Songs are a third budget.
    #
    # Like the camera's pools (`PoolLimit`), these are arcana-core lanes, waited for
    # BEFORE a request takes a toolset slot, so a backlog in one lane holds up no other.
    #
    # Lanes are per toolset. No provider serves both mj:camera and mj:voice under one
    # limit today: OpenAI is in both, but limits each model on its own. A provider that
    # did (Runware for speech as well as pictures) would need a lane the two toolsets
    # share.
    module VoiceLanes
      # ElevenLabs' speech at once, by plan: v3 and v2, then Flash and Turbo (its models
      # page and TTS FAQ, 2026-10-21; Starter's measured). A plan not listed here (Free,
      # Business, Enterprise) gets Starter's, and a 429 is retried in any case.
      ELEVENLABS_PLANS = {
        "starter" => {3, 6},
        "creator" => {5, 10},
        "pro"     => {10, 20},
        "scale"   => {15, 30},
      }

      # Songs: the plan allows 2 (Scale 5); 1 here, so songs, which take minutes, hold no
      # more. OpenAI limits requests per minute rather than at once, so 6 is politeness.
      SONGS  = 1
      OPENAI = 6

      # How many of each lane run at once on the ElevenLabs plan `tier`.
      def self.limits(tier : String?) : Hash(String, Int32)
        speech, flash = ELEVENLABS_PLANS[tier]? || ELEVENLABS_PLANS["starter"]
        {"elevenlabs" => speech, "elevenlabs-flash" => flash, "elevenlabs-music" => SONGS, "openai" => OPENAI}
      end

      SUBSCRIPTION = URI.parse("https://api.elevenlabs.io/v1/user/subscription")

      # The account's plan ("starter", "pro", ...), asked of ElevenLabs when the service
      # starts, so a change of plan takes a restart; nil if it can't be read.
      def self.elevenlabs_tier : String?
        key = ENV["ELEVENLABS_API_KEY"]? || return nil
        client = HTTP::Client.new(SUBSCRIPTION)
        client.connect_timeout = 5.seconds
        client.read_timeout = 10.seconds
        r = client.get(SUBSCRIPTION.path, headers: HTTP::Headers{"xi-api-key" => key})
        JSON.parse(r.body)["tier"]?.try(&.as_s?) if r.success?
      rescue
        nil
      ensure
        client.try &.close
      end

      # The lane for one request; nil for the tools that call no provider.
      def self.for(data : JSON::Any) : String?
        case data["tool"]?.try(&.as_s?)
        when "music"
          "elevenlabs-music"
        when "speak"
          case data["provider"]?.try(&.as_s?) || "openai"
          when "elevenlabs"
            model = data["model"]?.try(&.as_s?) || ::Arcana::AI::TTS::ElevenLabs::DEFAULT_MODEL
            flash?(model) ? "elevenlabs-flash" : "elevenlabs"
          when "openai"
            "openai"
          end
        end
      end

      # eleven_flash_v2_5, eleven_turbo_v2_5 and their v2s share the higher limit.
      def self.flash?(model : String) : Bool
        model.includes?("flash") || model.includes?("turbo")
      end
    end
  end
end
