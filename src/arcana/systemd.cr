require "socket"

module MJ
  module Arcana
    # Tells systemd how the service is doing, for a unit with Type=notify: `READY=1` once
    # mj:camera and mj:voice have joined the bus, so a unit ordered After=mj-arcana.service
    # (the game, on the Overlore box) starts only when mj can answer (@overlore for Thomas,
    # 2026-10-25).
    #
    # The message is one datagram to the socket named in NOTIFY_SOCKET. A leading '@' names
    # the abstract namespace: a NUL in its place, and an address length that counts only the
    # name. Socket::UNIXAddress always passes the whole sockaddr_un, which turns an abstract
    # name into a different one padded with NULs, so the address is built here.
    module Systemd
      ENV_VAR = "NOTIFY_SOCKET"

      # Sends `state` (lines such as "READY=1"); false, sending nothing, outside systemd.
      def self.notify(state : String, socket : String? = ENV[ENV_VAR]?) : Bool
        return false unless socket && !socket.empty?
        name = socket.starts_with?('@') ? "\0#{socket[1..]}" : socket
        addr = LibC::SockaddrUn.new
        if name.bytesize >= addr.sun_path.size
          raise ArgumentError.new("#{ENV_VAR} is longer than a socket address holds: #{socket}")
        end
        addr.sun_family = LibC::SaFamilyT.new(LibC::AF_UNIX)
        name.to_slice.copy_to(addr.sun_path.to_unsafe.as(UInt8*), name.bytesize)
        len = offsetof(LibC::SockaddrUn, @sun_path) + name.bytesize
        fd = LibC.socket(LibC::AF_UNIX, LibC::SOCK_DGRAM | LibC::SOCK_CLOEXEC, 0)
        raise RuntimeError.from_errno("socket for #{ENV_VAR}") if fd < 0
        begin
          sent = LibC.sendto(fd, state.to_unsafe, state.bytesize, 0, pointerof(addr).as(LibC::Sockaddr*), len)
          raise RuntimeError.from_errno("sending to #{ENV_VAR} #{socket}") if sent < 0
          true
        ensure
          LibC.close(fd)
        end
      end
    end
  end
end
