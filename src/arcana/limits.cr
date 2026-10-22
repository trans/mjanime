require "json"
require "./fetch_reference"

module MJ
  module Arcana
    # The most one request may ask for, set far above anything a game sends. Overlore caps
    # request sizes itself, and a limit tight enough to meet a real request would stop the
    # game (Thomas, 2026-10-22), so these stop only the obviously outrageous: a caller gone
    # wrong. Checked before anything is queued or billed.
    module Limits
      TEXT       = 10_000 # characters in any one text field, about 10 minutes of speech
      SONG       = 10.minutes
      REFERENCES = 16 # four is the most measured (see the camera's schema)
      WAIT       = 1.hour

      def self.text!(data : JSON::Any, *fields : String)
        fields.each do |f|
          next unless s = data[f]?.try(&.as_s?)
          refuse "#{f} is #{s.size} characters, over #{TEXT}" if s.size > TEXT
        end
      end

      def self.wait!(data : JSON::Any)
        wait = data["wait_seconds"]?.try { |v| v.as_f? || v.as_i64?.try(&.to_f) }
        refuse "wait_seconds is #{wait == wait.to_i ? wait.to_i : wait}, over #{WAIT.total_seconds.to_i}" if wait && wait > WAIT.total_seconds
      end

      # A plan's length is its sections' lengths; a prompt's is music_length_ms, if given.
      def self.song!(data : JSON::Any)
        ms =
          if sections = data["composition_plan"]?.try(&.["sections"]?).try(&.as_a?)
            sections.sum { |s| s["duration_ms"]?.try { |d| d.as_i64? || d.as_f?.try(&.to_i64) } || 0_i64 }
          else
            data["music_length_ms"]?.try(&.as_i64?) || 0_i64
          end
        refuse "the song is #{ms // 1000} s, over #{SONG.total_seconds.to_i}" if ms > SONG.total_milliseconds
      end

      # Counted before any is fetched, and base64 held to the size a fetched one may be.
      def self.references!(data : JSON::Any)
        {"references_url", "references_base64"}.each do |f|
          next unless list = data[f]?.try(&.as_a?)
          refuse "#{f} has #{list.size} references, over #{REFERENCES}" if list.size > REFERENCES
        end
        b64 = (data["references_base64"]?.try(&.as_a?) || [] of JSON::Any) + [data["reference_base64"]?].compact
        b64.each do |node|
          next unless s = node.as_s?
          refuse "a reference is over #{FetchReference::MAX_BYTES // (1024 * 1024)} MB" if s.size // 4 * 3 > FetchReference::MAX_BYTES
        end
      end

      private def self.refuse(why : String)
        raise "#{why}. mj refuses only what no game would send. Nothing was billed."
      end
    end
  end
end
