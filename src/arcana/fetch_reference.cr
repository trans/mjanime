require "http/client"
require "uri"
require "../api/image_sniff"

module MJ
  module Arcana
    # Fetch a reference image by URL.
    #
    # Overlore sends a portrait with every panel and wanted the bytes off the bus. With
    # DataDungeon's store in a bucket that is a presigned URL; with local storage it is
    # `http://127.0.0.1:<port>/media/<key>`, since caller and service share the machine.
    #
    # **We fetch it rather than passing the URL through to the provider, and the localhost
    # case is why.** Runware's `inputImage` does accept a URL, so a public bucket link
    # could in principle go straight through and save a round trip. A loopback URL cannot:
    # Runware's servers have no route to the caller's 127.0.0.1. Handling only the public
    # case would mean a parameter that works for one caller's storage backend and fails
    # confusingly for another's, so this always fetches. The goal was to keep bytes off the
    # BUS, which it does completely.
    #
    # Pass-through for genuinely public URLs remains a possible optimisation. It saves one
    # download and one upload per shot, and would need the transport interface to carry
    # "bytes or URL" rather than bytes.
    module FetchReference
      class Error < Exception; end

      # Generous for a local store, bounded so a mistyped URL pointing at something huge
      # cannot exhaust memory.
      MAX_BYTES = 32 * 1024 * 1024
      # One hop, so a redirect loop cannot hold the request open.
      MAX_REDIRECTS = 2

      def self.fetch(url : String) : Bytes
        bytes = get(url, 0)
        # Fail here with a clear message rather than letting a provider reject it with its
        # own. A caller pointing at an HTML error page gets told so.
        unless ImageSniff.png?(bytes) || ImageSniff.jpeg?(bytes) ||
               ImageSniff.webp?(bytes) || ImageSniff.gif?(bytes)
          head = String.new(bytes[0, Math.min(48, bytes.size)]).gsub(/[^[:print:]]/, ".")
          raise Error.new("#{url} did not return an image — first bytes look like #{head.inspect}")
        end
        bytes
      end

      private def self.get(url : String, depth : Int32) : Bytes
        raise Error.new("too many redirects fetching #{url}") if depth > MAX_REDIRECTS
        uri = URI.parse(url)
        scheme = uri.scheme
        unless scheme == "http" || scheme == "https"
          raise Error.new("reference_url must be http or https, not #{scheme.inspect}")
        end

        client = HTTP::Client.new(uri)
        client.connect_timeout = 10.seconds
        client.read_timeout = 30.seconds
        begin
          response = client.get(uri.request_target)
          if response.status.redirection? && (loc = response.headers["Location"]?)
            return get(URI.parse(url).resolve(loc).to_s, depth + 1)
          end
          unless response.status_code == 200
            raise Error.new("fetching #{url} returned #{response.status_code}")
          end
          body = response.body
          if body.bytesize > MAX_BYTES
            raise Error.new("#{url} returned #{body.bytesize} bytes, over the #{MAX_BYTES} cap")
          end
          body.to_slice
        rescue ex : IO::TimeoutError | IO::Error | Socket::Error
          raise Error.new("could not fetch #{url}: #{ex.message}")
        ensure
          client.close
        end
      end
    end
  end
end
