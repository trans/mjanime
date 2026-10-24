require "arcana-core"

module MJ
  module Arcana
    # Who may call mj:camera and mj:voice. With no list, anyone on the bus: that is the
    # workstation, where keeping a list would only get in the way. A deployment sets one
    # (`MJ_ARCANA_CALLERS=overlore` in /etc/mj/env) and is served only by those addresses
    # (Thomas, 2026-10-24).
    #
    # A listed caller must also come `verified`, the bus's stamp that the sender proved
    # `from` is its own (arcana 0.37). `from` alone is whatever the sender wrote, so a list
    # without the stamp would stop no one. So a caller without a key is turned away once a
    # list is set: Overlore's REST calls must sign before its box sets one.
    #
    # `help` is answered by the Toolset before any tool runs, so it stays open to all.
    module Callers
      ENV_VAR = "MJ_ARCANA_CALLERS"

      # Addresses, split on commas or spaces; nil when there are none.
      def self.parse(s : String?) : Array(String)?
        list = s.to_s.split(/[\s,]+/).reject(&.empty?)
        list.empty? ? nil : list
      end

      class_getter allowed : Array(String)? { parse(ENV[ENV_VAR]?) }

      # Raises, before anything is queued or billed, unless the envelope may be served.
      def self.check!(envelope : ::Arcana::Envelope, allowed : Array(String)? = self.allowed)
        return unless allowed
        unless allowed.includes?(envelope.from)
          refuse envelope, "#{envelope.from.inspect} isn't a caller this service serves"
        end
        unless envelope.verified
          refuse envelope, "the bus didn't verify that #{envelope.from.inspect} sent this; " \
                           "sign with the project's key (arcana 0.37)"
        end
      end

      private def self.refuse(envelope : ::Arcana::Envelope, why : String)
        STDERR.puts "[callers] refused #{envelope.from.inspect} → #{envelope.to}: #{why}"
        raise "#{why}. Nothing was billed."
      end
    end
  end
end
