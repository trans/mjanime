require "http/client"
require "openssl"
require "socket"
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
    #
    # **Where it may fetch from** (the security review, 2026-10-21). Any bus participant
    # can name the URL, so an unchecked fetch is a way into the droplet's own network: its
    # metadata service at 169.254.169.254, or any service listening on loopback. So the
    # host is resolved, its addresses are checked, and the connection goes to one that
    # passed, never to a second lookup that could answer differently (DNS rebinding). Redirects are checked the same way, hop by hop. Allowed: public
    # addresses over http or https, and loopback over http for paths under `/media/`,
    # the shape of DataDungeon's local store. A failure says why without echoing what
    # came back, since that could be an internal service's reply.
    module FetchReference
      class Error < Exception; end

      # Generous for a local store, bounded so a mistyped URL pointing at something huge
      # cannot exhaust memory: counted while reading, never after.
      MAX_BYTES     = 32 * 1024 * 1024
      MAX_REDIRECTS = 2
      # A local store's path: under /media/, plain characters only, so neither `..` nor a
      # percent-escape can step out of it.
      LOCAL_MEDIA = %r{\A/media/(?!.*\.\.)[A-Za-z0-9._~/-]+\z}
      # The whole fetch, redirects included, so a server trickling bytes can't hold it.
      DEADLINE = 60.seconds

      def self.fetch(url : String) : Bytes
        bytes = get(URI.parse(url), 0, Time.instant + DEADLINE)
        # Fail here with a clear message rather than letting a provider reject it with its
        # own. A caller pointing at an HTML error page gets told so.
        unless ImageSniff.png?(bytes) || ImageSniff.jpeg?(bytes) ||
               ImageSniff.webp?(bytes) || ImageSniff.gif?(bytes)
          raise Error.new("#{shown(URI.parse(url))} did not return a PNG, JPEG, WebP or GIF image")
        end
        bytes
      end

      private def self.get(uri : URI, depth : Int32, deadline : Time::Instant) : Bytes
        raise Error.new("too many redirects fetching #{shown(uri)}") if depth > MAX_REDIRECTS
        scheme = uri.scheme
        unless scheme == "http" || scheme == "https"
          raise Error.new("reference_url must be http or https, not #{scheme.inspect}")
        end
        host = uri.hostname.presence || raise Error.new("reference_url has no host")
        port = uri.port || (scheme == "https" ? 443 : 80)
        ip = allowed_address(uri, host, port)

        tcp = TCPSocket.new(ip.address, port, connect_timeout: 10.seconds)
        tcp.read_timeout = 30.seconds
        io = if scheme == "https"
               OpenSSL::SSL::Socket::Client.new(tcp, OpenSSL::SSL::Context::Client.new,
                 sync_close: true, hostname: host)
             else
               tcp
             end
        client = HTTP::Client.new(io, host, port)
        # Exactly the URL's host, as a presigned URL's signature expects.
        headers = HTTP::Headers{"Host" => uri.port ? "#{uri.host}:#{uri.port}" : uri.host.to_s}
        # A failure found while reading is kept and raised once the client is done: raised
        # inside the block, it is lost to the client's own error as it drains and retries.
        failure = nil.as(Error?)
        next_uri = nil.as(URI?)
        bytes = nil.as(Bytes?)
        begin
          client.get(uri.request_target, headers: headers) do |response|
            if response.status.redirection? && (loc = response.headers["Location"]?)
              next_uri = uri.resolve(loc)
            elsif response.status_code != 200
              failure = Error.new("fetching #{shown(uri)} returned #{response.status_code}")
            elsif (n = response.headers["Content-Length"]?.try(&.to_i64?)) && n > MAX_BYTES
              failure = Error.new("#{shown(uri)} is #{n} bytes, over the #{MAX_BYTES} cap")
            else
              begin
                bytes = read_capped(response.body_io, uri, deadline)
              rescue ex : Error
                failure = ex
                io.close # stop the transfer rather than drain it
              end
            end
          end
        rescue ex
          raise failure || Error.new("could not fetch #{shown(uri)}: #{ex.message}")
        ensure
          client.close
        end
        failure.try { |f| raise f }
        return bytes if bytes
        get(next_uri.not_nil!, depth + 1, deadline)
      end

      private def self.read_capped(body : IO, uri : URI, deadline : Time::Instant) : Bytes
        buf = IO::Memory.new
        chunk = Bytes.new(64 * 1024)
        while (n = body.read(chunk)) > 0
          buf.write(chunk[0, n])
          raise Error.new("#{shown(uri)} is over the #{MAX_BYTES} cap") if buf.size > MAX_BYTES
          raise Error.new("fetching #{shown(uri)} took over #{DEADLINE.total_seconds.to_i} s") if Time.instant > deadline
        end
        buf.to_slice
      end

      # The first address the host resolves to that may be fetched from.
      private def self.allowed_address(uri : URI, host : String, port : Int32) : Socket::IPAddress
        addrs = begin
          Socket::Addrinfo.tcp(host, port, timeout: 10.seconds).map(&.ip_address)
        rescue ex : Socket::Error
          raise Error.new("could not resolve #{host}: #{ex.message}")
        end
        addrs.each do |ip|
          return ip if public?(ip)
          return ip if ip.loopback? && uri.scheme == "http" && LOCAL_MEDIA.matches?(uri.path)
        end
        raise Error.new("#{shown(uri)} is not a public address: reference_url fetches from " \
                        "public hosts, or from loopback over http under /media/")
      end

      # Globally routable: not private, loopback, link-local, shared (CGNAT), reserved,
      # documentation, multicast or unspecified.
      def self.public?(ip : Socket::IPAddress) : Bool
        return false if ip.loopback? || ip.private? || ip.link_local? || ip.unspecified?
        a = ip.address
        v4 = a.includes?('.') ? a.split(':').last : nil # IPv4, or IPv4 inside IPv6
        if v4
          o = v4.split('.').map(&.to_i)
          return false if o[0] == 0 || o[0] == 10 || o[0] == 127 || o[0] >= 224
          return false if o[0] == 100 && (64..127).includes?(o[1]) # shared, CGNAT
          return false if o[0] == 169 && o[1] == 254               # link-local
          return false if o[0] == 172 && (16..31).includes?(o[1])  # private
          return false if o[0] == 192 && (o[1] == 168 || (o[1] == 0 && {0, 2}.includes?(o[2])))
          return false if o[0] == 198 && ((18..19).includes?(o[1]) || (o[1] == 51 && o[2] == 100))
          return false if o[0] == 203 && o[1] == 0 && o[2] == 113
          true
        else
          first = a.split(':').first.presence.try(&.to_i(16)) || 0
          return false unless (0x2000..0x3fff).includes?(first) # global unicast, 2000::/3
          !a.downcase.starts_with?("2001:db8:")                 # documentation
        end
      end

      # A URL as shown in an error: without its query, which for a presigned link holds
      # the signature.
      private def self.shown(uri : URI) : String
        "#{uri.scheme}://#{uri.host}#{uri.port ? ":#{uri.port}" : ""}#{uri.path}"
      end
    end
  end
end
