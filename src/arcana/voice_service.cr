require "arcana-core"
require "arcana-ai"
require "base64"
require "http/client"
require "json"
require "./tts_rates"

module MJ
  module Arcana
    # The voice service — ported out of the arcana server.
    #
    # Arcana supplies the bus; it should not also own every provider integration, or it
    # becomes a monolith with a bus inside it. The TTS provider code stays in arcana-ai
    # (a library); what moves here is the EXPOSURE of it as a service.
    #
    # Ported with one change worth having: arcana only ever exposed OpenAI, while
    # arcana-ai has had a complete ElevenLabs provider sitting unused. Both are offered
    # here, chosen per call.
    module VoiceService
      OPENAI_VOICES = %w(alloy ash ballad coral echo fable onyx nova sage shimmer verse)

      SPEAK_SCHEMA = JSON.parse(%<{
        "type":"object",
        "required":["text"],
        "description":"Synthesize speech. Returns base64 audio unless output_path is given — bus services are filesystem-isolated, so base64 is the portable answer.",
        "properties":{
          "text":{"type":"string","description":"What to say."},
          "provider":{"type":"string","enum":["openai","elevenlabs"],"description":"Default openai. elevenlabs needs ELEVENLABS_API_KEY."},
          "voice":{"type":"string","description":"openai: alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, verse. elevenlabs: a voice id."},
          "model":{"type":"string","description":"Override the provider's default model."},
          "format":{"type":"string","description":"mp3, wav, aac, flac, opus, pcm (default opus)."},
          "instructions":{"type":"string","description":"Style/persona direction. OpenAI only."},
          "speed":{"type":"number","description":"0.25-4.0. OpenAI only."},
          "previous_text":{"type":"string","description":"Preceding line, for prosody continuity. ElevenLabs only, and not eleven_v3, which refuses it with a 400."},
          "next_text":{"type":"string","description":"Following line, for prosody continuity. ElevenLabs only."},
          "output_path":{"type":"string","description":"Write the audio here instead of returning base64."}
        }
      }>)

      VOICES_SCHEMA = JSON.parse(%<{"type":"object","properties":{}}>)

      MUSIC_SCHEMA = JSON.parse(%<{
        "type":"object",
        "description":"A song from Eleven Music, sung, from a composition plan or a prompt. It takes no voice id. Returns base64 audio unless output_path is given. Needs ELEVENLABS_API_KEY.",
        "properties":{
          "composition_plan":{"type":"object","description":"ElevenLabs' plan: positive_global_styles, negative_global_styles, and sections, each {section_name, positive_local_styles, negative_local_styles, duration_ms, lines}. The sections set the length."},
          "prompt":{"type":"string","description":"A text prompt instead of a plan."},
          "music_length_ms":{"type":"integer","description":"With a prompt only: the length in ms."},
          "model":{"type":"string","description":"Default music_v1."},
          "format":{"type":"string","description":"ElevenLabs' output_format, default mp3_44100_128."},
          "output_path":{"type":"string","description":"Write the audio here instead of returning base64."}
        }
      }>)

      def self.register(ts : ::Arcana::Toolset)
        ts.tool("voices", "List the speech providers available on this host and their voices.",
          input_schema: VOICES_SCHEMA) { |_, _ctx| handle_voices }
        ts.tool("speak", "Synthesize speech from text.",
          input_schema: SPEAK_SCHEMA) { |data, _ctx| handle_speak(data) }
        ts.tool("music", "A sung song from Eleven Music, from a composition plan or a prompt.",
          input_schema: MUSIC_SCHEMA) { |data, _ctx| handle_music(data) }
      end

      def self.available : Array(String)
        out = [] of String
        out << "openai" if ENV["OPENAI_API_KEY"]?
        out << "elevenlabs" if ENV["ELEVENLABS_API_KEY"]?
        out
      end

      def self.handle_voices : JSON::Any
        JSON.parse({
          "providers" => available,
          "openai"    => {
            "voices"  => OPENAI_VOICES,
            "default" => "alloy",
            "note"    => "Supports `instructions` (persona direction) and `speed`.",
          },
          "elevenlabs" => {
            "voices"  => "any ElevenLabs voice id",
            "default" => ::Arcana::AI::TTS::ElevenLabs::DEFAULT_VOICE,
            "models"  => ELEVENLABS_MODELS,
            "note"    => "Supports `previous_text` / `next_text` for prosody continuity " \
                      "across consecutive lines — useful when narrating in sequence.",
          },
          "music" => {
            "available" => !ENV["ELEVENLABS_API_KEY"]?.nil?,
            "provider"  => "elevenlabs",
            "models"    => [MUSIC_MODEL],
            "note"      => "{\"tool\":\"music\"} with a composition_plan or a prompt.",
          },
        }.to_json)
      end

      # arcana-ai's list stops at v2.5. Any model name passes through to ElevenLabs as given,
      # but callers read this list to see what's there, so v3 has to be on it.
      ELEVENLABS_MODELS = (::Arcana::AI::TTS::ElevenLabs::MODELS + ["eleven_v3"]).uniq

      # --- music ---------------------------------------------------------------------------
      #
      # Eleven Music, called directly: arcana-ai has no music provider. It sings, but it
      # takes no voice id, so a song is in a voice's manner, not its voice.
      MUSIC_ENDPOINT = "https://api.elevenlabs.io/v1/music"
      MUSIC_MODEL    = "music_v1"
      MUSIC_FORMAT   = "mp3_44100_128"
      # A plan or prompt it won't take comes back as one of these, often with a suggestion.
      MUSIC_REFUSALS = ["bad_prompt", "bad_composition_plan"]

      def self.handle_music(data : JSON::Any) : JSON::Any
        key = ENV["ELEVENLABS_API_KEY"]? || raise "ELEVENLABS_API_KEY is not set on this host"
        plan = data["composition_plan"]?
        prompt = data["prompt"]?.try(&.as_s?)
        raise "music takes a composition_plan or a prompt, not both" if plan && prompt
        model = data["model"]?.try(&.as_s?) || MUSIC_MODEL
        format = data["format"]?.try(&.as_s?) || MUSIC_FORMAT

        body = {"model_id" => JSON::Any.new(model)}
        if plan
          body["composition_plan"] = plan
        elsif prompt
          body["prompt"] = JSON::Any.new(prompt)
          if ms = data["music_length_ms"]?.try(&.as_i64?)
            body["music_length_ms"] = JSON::Any.new(ms)
          end
        else
          raise "music requires a composition_plan or a prompt"
        end

        uri = URI.parse("#{MUSIC_ENDPOINT}?output_format=#{URI.encode_www_form(format)}")
        client = HTTP::Client.new(uri)
        client.connect_timeout = 30.seconds
        client.read_timeout = 600.seconds # a song takes far longer than a spoken line
        headers = HTTP::Headers{"xi-api-key" => key, "Content-Type" => "application/json"}
        response = client.post(uri.request_target, headers: headers, body: body.to_json)

        unless response.success?
          msg = response.body
          if MUSIC_REFUSALS.any? { |r| msg.includes?(r) } || refusal?(msg)
            return JSON::Any.new({
              "status"   => JSON::Any.new("refused"),
              "provider" => JSON::Any.new("elevenlabs"),
              "reason"   => (JSON.parse(msg) rescue JSON::Any.new(msg[0, 400])),
              "retry"    => JSON::Any.new(true),
              "note"     => JSON::Any.new("ElevenLabs declined this plan or prompt; its reason " \
                                          "may carry a suggested rewrite. Not billed."),
            } of String => JSON::Any)
          end
          raise "Eleven Music error (#{response.status_code}): #{msg[0, 400]}"
        end

        audio = response.body.to_slice
        container = format.split('_').first
        billed = response.headers["character-cost"]?.try(&.to_i64?)
        h = {
          "status"           => JSON::Any.new("ok"),
          "provider"         => JSON::Any.new("elevenlabs"),
          "model"            => JSON::Any.new(model),
          "format"           => JSON::Any.new(format),
          "duration_seconds" => TtsRates.duration(audio, container).try { |s| JSON::Any.new(s.round(3)) } || JSON::Any.new(nil),
          # Unlike speech, a song's response has carried no cost header; null means unknown.
          "billed_characters" => billed ? JSON::Any.new(billed) : JSON::Any.new(nil),
          "usd"               => JSON::Any.new(nil),
          "usd_basis"         => JSON::Any.new("Eleven Music returned no cost; see the account's usage page"),
          "content_type"   => JSON::Any.new(response.headers["Content-Type"]? || ""),
          "content_length" => JSON::Any.new(audio.size.to_i64),
        } of String => JSON::Any
        if song = response.headers["song-id"]?
          h["song_id"] = JSON::Any.new(song)
        end
        if path = data["output_path"]?.try(&.as_s?)
          File.write(path, audio)
          h["output_path"] = JSON::Any.new(path)
        else
          h["audio_base64"] = JSON::Any.new(Base64.strict_encode(audio))
        end
        JSON::Any.new(h)
      end

      REFUSAL_MARKERS = ["content_policy", "content policy", "moderation", "rejected",
                         "flagged", "safety"]

      def self.refusal?(message : String) : Bool
        m = message.downcase
        REFUSAL_MARKERS.any? { |r| m.includes?(r) }
      end

      # One builder for both paths, so inline and on-disk results cannot drift apart.
      #
      # `duration_seconds` is worth having on its own account, quite apart from billing:
      # a comic that pairs a panel with a spoken line needs to know how long to hold it,
      # and a lip-sync pass needs the length before it can retime anything.
      private def self.ok_result(provider : String, result : ::Arcana::AI::TTS::Result,
                                 voice : String, format : String, text : String,
                                 seconds : Float64?)
        model = result.model
        usd, exact, basis = price(provider, result, text.size, seconds)
        h = {
          "status"     => JSON::Any.new("ok"),
          "provider"   => JSON::Any.new(provider),
          "model"      => JSON::Any.new(model),
          "voice"      => JSON::Any.new(voice),
          "format"     => JSON::Any.new(format),
          "characters" => JSON::Any.new(text.size.to_i64),
          # The provider returns no price, so this is computed. `usd_exact` is the whole
          # point of reporting it: true means the billing unit is one we hold exactly
          # (the characters or tokens the provider reported, or tts-1's characters, against
          # a published rate), false means it was derived from measured duration or a
          # configured rate. nil usd means genuinely unknown —
          # a guess is never dressed up as a figure, because it would land in someone
          # else's ledger as fact.
          "usd"       => usd ? JSON::Any.new(usd) : JSON::Any.new(nil),
          "usd_exact" => JSON::Any.new(usd ? exact : false),
          "usd_basis" => JSON::Any.new(basis),
        } of String => JSON::Any
        h["duration_seconds"] = seconds ? JSON::Any.new(seconds.round(3)) : JSON::Any.new(nil)
        if provider == "elevenlabs"
          # What ElevenLabs says it billed, which can be fewer than `characters`; null if it
          # didn't say.
          billed = result.usage.try(&.characters)
          h["billed_characters"] = billed ? JSON::Any.new(billed) : JSON::Any.new(nil)
        end
        h["content_type"] = JSON::Any.new(result.content_type)
        h["content_length"] = JSON::Any.new(result.content_length)
        h
      end

      # arcana-ai prices what the provider reports billing, at the published per-model
      # rate, so this is exact when priced: ElevenLabs' characters (its `character-cost`
      # header), and OpenAI's input and audio tokens (the event stream's last event, on
      # every model but tts-1 and tts-1-hd). It prices a dated snapshot at its model's
      # rates, so a caller pinning gpt-4o-mini-tts-2025-12-15 gets a price too (it got
      # none from TtsRates, 2026-10-19). OpenAI without usage falls back to TtsRates:
      # exact for tts-1's characters, an estimate from duration otherwise.
      private def self.price(provider : String, result : ::Arcana::AI::TTS::Result,
                             characters : Int32, seconds : Float64?) : {Float64?, Bool, String}
        case cost = result.cost
        when ::Arcana::AI::Pricing::Cost
          who = provider == "elevenlabs" ? "ElevenLabs" : "OpenAI"
          lines = cost.lines.map { |l|
            per = l.unit == "tokens" ? "1M" : "1,000"
            what = l.item == l.unit ? l.unit : "#{l.item} #{l.unit}"
            "#{l.quantity} #{what} at $#{l.rate} per #{per}"
          }
          basis = lines.empty? ? "priced by arcana-ai" : "#{who} billed #{lines.join(" and ")}"
          basis += ", priced as #{cost.priced_as}" if cost.priced_as != cost.model
          {cost.total.to_f, true, "#{basis} (#{cost.rates})"}
        else
          if provider == "openai"
            TtsRates.price(provider, result.model, characters, seconds)
          else
            {nil, false, cost.detail}
          end
        end
      end

      def self.handle_speak(data : JSON::Any) : JSON::Any
        text = data["text"]?.try(&.as_s?) || raise "speak requires 'text'"
        provider = data["provider"]?.try(&.as_s?) || "openai"
        format = data["format"]?.try(&.as_s?) || "opus"

        tts =
          case provider
          when "openai"
            key = ENV["OPENAI_API_KEY"]? || raise "OPENAI_API_KEY is not set on this host"
            ::Arcana::AI::TTS::OpenAI.new(api_key: key)
          when "elevenlabs"
            key = ENV["ELEVENLABS_API_KEY"]? || raise "ELEVENLABS_API_KEY is not set on this host"
            m = data["model"]?.try(&.as_s?)
            v = data["voice"]?.try(&.as_s?)
            if m && v
              ::Arcana::AI::TTS::ElevenLabs.new(api_key: key, model: m, voice_id: v)
            elsif m
              ::Arcana::AI::TTS::ElevenLabs.new(api_key: key, model: m)
            elsif v
              ::Arcana::AI::TTS::ElevenLabs.new(api_key: key, voice_id: v)
            else
              ::Arcana::AI::TTS::ElevenLabs.new(api_key: key)
            end
          else
            raise "unknown provider #{provider.inspect} — expected openai or elevenlabs"
          end

        # Empty means "the provider's own default" — arcana-ai 0.3.0 changed these from
        # OpenAI's defaults to "" precisely because the old ones leaked across providers:
        # ElevenLabs was being sent model "gpt-4o-mini-tts" and voice "alloy" on every
        # call, overriding the constructor. Never substitute one provider's default here.
        req = ::Arcana::AI::TTS::Request.new(
          text: text,
          voice: data["voice"]?.try(&.as_s?) || "",
          model: data["model"]?.try(&.as_s?) || "",
          response_format: format,
          instructions: data["instructions"]?.try(&.as_s?),
          speed: data["speed"]?.try(&.as_f?),
          previous_text: data["previous_text"]?.try(&.as_s?),
          next_text: data["next_text"]?.try(&.as_s?),
        )

        # `Result` does not carry the voice actually used, so resolve it for the report:
        # the caller needs to know WHICH voice spoke, not that it asked for the default.
        effective_voice =
          if v = data["voice"]?.try(&.as_s?)
            v
          elsif provider == "elevenlabs"
            ::Arcana::AI::TTS::ElevenLabs::DEFAULT_VOICE
          else
            "alloy"
          end

        begin
          if path = data["output_path"]?.try(&.as_s?)
            result = tts.synthesize(req, path)
            JSON::Any.new(ok_result(provider, result, effective_voice, format, text,
              TtsRates.duration(path)).tap { |h|
              h["output_path"] = JSON::Any.new(result.output_path)
            })
          else
            # arcana-ai 0.3.0 added the in-memory overload, so the temp file is gone.
            # ffprobe measures duration straight off the bytes through a pipe.
            result = tts.synthesize(req)
            JSON::Any.new(ok_result(provider, result, effective_voice, format, text,
              TtsRates.duration(result.audio, format)).tap { |h|
              h["audio_base64"] = JSON::Any.new(Base64.strict_encode(result.audio))
            })
          end
        rescue ex
          msg = ex.message || "unknown"
          raise ex unless refusal?(msg)
          JSON::Any.new({
            "status"   => JSON::Any.new("refused"),
            "provider" => JSON::Any.new(provider),
            "usd"      => JSON::Any.new(0.0),
            "reason"   => JSON::Any.new(msg[0, 400]),
            "retry"    => JSON::Any.new(true),
            "note"     => JSON::Any.new(
              "The provider refused this text. Not billed. Never substituted with " \
              "another provider — that would corrupt your logs."),
          } of String => JSON::Any)
        end
      end
    end
  end
end
