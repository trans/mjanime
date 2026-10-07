require "json"

module MJ
  module Arcana
    # What a spoken line cost — the same per-provider knowledge `cameras.cr` holds for
    # images, for speech.
    #
    # Unlike Runware, no TTS provider reports a price in the response, so this has to be
    # computed. The trap is assuming one billing unit: the two providers do not share one.
    #
    #   OpenAI gpt-4o-mini-tts   billed per TOKEN — $0.60/1M input characters plus
    #                            $12.00/1M AUDIO OUTPUT tokens. Audio tokens track
    #                            duration, so DURATION is the cost driver and OpenAI
    #                            publishes a composite of ~$0.015/minute.
    #   OpenAI tts-1 / tts-1-hd  billed per CHARACTER, $15 / $30 per 1M. Exactly
    #                            computable from the text — no estimate needed.
    #   ElevenLabs               billed per CHARACTER in credits. The character count is
    #                            exact, but a credit's DOLLAR value depends on the
    #                            subscription tier, so the dollar figure cannot be known
    #                            here without being told the rate.
    #
    # So: character-billed models get an EXACT price, duration-billed ones get an estimate
    # from measured duration, and ElevenLabs gets a price only once a rate is configured.
    # Each result says which rule produced it rather than leaving the caller to guess.
    #
    # Published prices drift. Every figure here is overridable by environment variable,
    # and `basis` names the rule so a stale number is visible rather than silent.
    module TtsRates
      # Published rates, as of 2026-10. NOT measured — unlike the camera costs, which come
      # from Runware's includeCost. Treat as a default to be overridden, not as truth.
      USD_PER_1M_CHARS = {
        "tts-1"    => 15.0,
        "tts-1-hd" => 30.0,
      }

      # Duration-billed models: OpenAI's own composite figure for text + audio tokens.
      USD_PER_MINUTE = {
        "gpt-4o-mini-tts" => 0.015,
      }

      # ElevenLabs bills credits per character, and the multiplier IS model-dependent:
      # the Flash and Turbo families are half price per character. This part is knowable;
      # only the dollars-per-credit is not.
      ELEVENLABS_CREDITS_PER_CHAR  = 1.0
      ELEVENLABS_HALF_PRICE_MODELS = ["flash", "turbo"]

      def self.elevenlabs_credits_per_char(model : String) : Float64
        ELEVENLABS_HALF_PRICE_MODELS.any? { |m| model.includes?(m) } ? 0.5 : ELEVENLABS_CREDITS_PER_CHAR
      end

      # The caller's plan rate, in USD per 1000 characters. Without it an ElevenLabs call
      # is unpriced — which is the honest answer, not a reason to invent a number.
      def self.elevenlabs_usd_per_1k : Float64?
        ENV["MJ_ELEVENLABS_USD_PER_1K_CHARS"]?.try(&.to_f?)
      end

      def self.openai_usd_per_minute(model : String) : Float64?
        if v = ENV["MJ_OPENAI_TTS_USD_PER_MINUTE"]?.try(&.to_f?)
          return v
        end
        USD_PER_MINUTE[model]?
      end

      def self.openai_usd_per_1m_chars(model : String) : Float64?
        USD_PER_1M_CHARS[model]?
      end

      # Returns {usd, exact?, basis}. `usd` nil means genuinely unknown — never a guess
      # dressed as a figure.
      def self.price(provider : String, model : String, characters : Int32,
                     seconds : Float64?) : {Float64?, Bool, String}
        case provider
        when "openai"
          # Character-billed models are exactly computable from the text alone.
          if per_1m = openai_usd_per_1m_chars(model)
            return {characters * per_1m / 1_000_000.0, true,
                    "#{model} bills per character at $#{per_1m}/1M — exact from #{characters} characters"}
          end
          # Token-billed models: audio output tokens track duration, so duration is the
          # estimator. Characters alone would miss how long the model chose to take.
          if per_min = openai_usd_per_minute(model)
            if s = seconds
              return {s / 60.0 * per_min, false,
                      "#{model} bills per token; audio tokens track duration, so estimated " \
                      "from #{s.round(2)}s of audio at $#{per_min}/minute (OpenAI's published composite)"}
            end
            return {nil, false,
                    "#{model} bills per token against audio duration, and duration could not " \
                    "be measured on this host (needs ffprobe)"}
          end
          {nil, false, "no rate known for model #{model}"}
        when "elevenlabs"
          mult = elevenlabs_credits_per_char(model)
          credits = characters * mult
          if per_1k = elevenlabs_usd_per_1k
            {credits * per_1k / 1000.0, false,
             "#{model} bills #{mult} credit(s)/character = #{credits.round(1)} credits; " \
             "priced at the configured $#{per_1k}/1k characters"}
          else
            {nil, false,
             "#{model} bills #{mult} credit(s)/character = #{credits.round(1)} credits, but a " \
             "credit's dollar value depends on your ElevenLabs plan. Set " \
             "MJ_ELEVENLABS_USD_PER_1K_CHARS to have this priced, or bill on `credits` yourself"}
          end
        else
          {nil, false, "unknown provider #{provider}"}
        end
      end

      # ffprobe is the only general answer — opus, mp3, aac and flac all need a decoder to
      # know their length, and this service's default is opus.
      #
      # It needs a SEEKABLE source, so the bytes get a short-lived temp file rather than a
      # pipe. Two things ruled the pipe out, and the first is the one that matters:
      #
      #   1. ffprobe cannot get a duration out of a piped Ogg stream at all — it reports
      #      N/A, because the length lives in the last page's granule position and it
      #      cannot seek there. mp3 pipes fine; opus, the default here, never does.
      #   2. Piping bytes to a subprocess worked in a standalone program and returned nil
      #      from inside the service's fiber for the same audio, where probing a path
      #      worked in both.
      #
      # Careful: `ffprobe - < file` SUCCEEDS where a true pipe fails, because shell
      # redirection hands over a seekable file descriptor. Testing that way proves nothing
      # about piping.
      #
      # This is a probe-only write of ~50KB, not a round-trip of the synthesis itself —
      # the audio still comes back in memory from arcana-ai 0.3.0 and is served from there.
      ARGS = ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0"]

      def self.duration(audio : Bytes, format : String) : Float64?
        return nil unless Process.find_executable("ffprobe")
        path = File.tempname("mj-probe-", ".#{format}")
        begin
          File.write(path, audio)
          duration(path)
        ensure
          File.delete(path) if File.exists?(path)
        end
      end

      def self.duration(path : String) : Float64?
        return nil unless Process.find_executable("ffprobe")
        buf = IO::Memory.new
        status = Process.run("ffprobe", ARGS + [path],
          output: buf, error: Process::Redirect::Close)
        return nil unless status.success?
        # ffprobe prints "N/A" rather than failing when it cannot determine a length.
        buf.to_s.strip.to_f?
      end
    end
  end
end
