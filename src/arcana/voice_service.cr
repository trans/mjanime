require "arcana-core"
require "arcana-ai"
require "base64"
require "json"

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
          "previous_text":{"type":"string","description":"Preceding line, for prosody continuity. ElevenLabs only."},
          "next_text":{"type":"string","description":"Following line, for prosody continuity. ElevenLabs only."},
          "output_path":{"type":"string","description":"Write the audio here instead of returning base64."}
        }
      }>)

      VOICES_SCHEMA = JSON.parse(%<{"type":"object","properties":{}}>)

      def self.register(ts : ::Arcana::Toolset)
        ts.tool("voices", "List the speech providers available on this host and their voices.",
          input_schema: VOICES_SCHEMA) { |_| handle_voices }
        ts.tool("speak", "Synthesize speech from text.",
          input_schema: SPEAK_SCHEMA) { |data| handle_speak(data) }
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
            "models"  => ::Arcana::AI::TTS::ElevenLabs::MODELS,
            "note"    => "Supports `previous_text` / `next_text` for prosody continuity " \
                         "across consecutive lines — useful when narrating in sequence.",
          },
        }.to_json)
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

        req = ::Arcana::AI::TTS::Request.new(
          text: text,
          voice: data["voice"]?.try(&.as_s?) || "alloy",
          response_format: format,
          instructions: data["instructions"]?.try(&.as_s?),
          speed: data["speed"]?.try(&.as_f?),
          previous_text: data["previous_text"]?.try(&.as_s?),
          next_text: data["next_text"]?.try(&.as_s?),
        )

        if path = data["output_path"]?.try(&.as_s?)
          result = tts.synthesize(req, path)
          JSON::Any.new({
            "output_path"    => JSON::Any.new(result.output_path),
            "provider"       => JSON::Any.new(provider),
            "model"          => JSON::Any.new(result.model),
            "content_type"   => JSON::Any.new(result.content_type),
            "content_length" => JSON::Any.new(result.content_length),
          })
        else
          # arcana-ai's Provider has no synthesize_bytes yet, so inline still round-trips
          # through a temp file. Its own TODO notes this; promote it there and this goes away.
          temp = File.tempname("mj-tts-", ".#{format}")
          begin
            result = tts.synthesize(req, temp)
            JSON::Any.new({
              "audio_base64"   => JSON::Any.new(Base64.strict_encode(File.read(temp))),
              "provider"       => JSON::Any.new(provider),
              "model"          => JSON::Any.new(result.model),
              "content_type"   => JSON::Any.new(result.content_type),
              "content_length" => JSON::Any.new(result.content_length),
            })
          ensure
            File.delete(temp) if File.exists?(temp)
          end
        end
      end
    end
  end
end
