require "http/request"

module MJ
  # `mj serve` is for this machine only, and has no login (the security review,
  # 2026-10-21). Two checks keep other sites out of it:
  #
  # - **The Host must name this machine.** A page can point its own domain at 127.0.0.1
  #   (DNS rebinding) and then read the studio as if it were its own; its requests still
  #   carry its domain as the Host.
  # - **A browser's cross-site request is refused** unless it only reads. A page you
  #   visit could otherwise post a form to `/soundbox/tts` or a render and spend money.
  #   Browsers say where a request came from in `Sec-Fetch-Site` and `Origin`; a request
  #   without them (curl, a script) isn't from a browser page, and passes.
  module WebGuard
    LOCAL_NAMES = {"localhost", "127.0.0.1", "[::1]"}
    SAFE        = {"GET", "HEAD", "OPTIONS"}

    def self.local_host?(host : String?, port : Int32) : Bool
      return false unless host
      LOCAL_NAMES.any? { |name| host == "#{name}:#{port}" || (port == 80 && host == name) }
    end

    def self.cross_site?(request : HTTP::Request, port : Int32) : Bool
      return false if SAFE.includes?(request.method)
      if site = request.headers["Sec-Fetch-Site"]?
        return true unless site == "same-origin" || site == "none"
      end
      if origin = request.headers["Origin"]?
        return true unless LOCAL_NAMES.any? { |name| origin == "http://#{name}:#{port}" }
      end
      false
    end
  end
end
