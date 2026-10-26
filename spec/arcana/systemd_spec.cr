require "spec"
require "socket"
require "../../src/arcana/systemd"

describe MJ::Arcana::Systemd do
  systemd = MJ::Arcana::Systemd

  it "sends nothing outside systemd" do
    systemd.notify("READY=1", nil).should be_false
    systemd.notify("READY=1", "").should be_false
  end

  it "sends the state as one datagram to the socket's path" do
    path = File.tempname("mj-notify", ".sock")
    sock = Socket.unix(Socket::Type::DGRAM)
    begin
      sock.bind(Socket::UNIXAddress.new(path))
      systemd.notify("READY=1\nSTATUS=ready", path).should be_true
      buf = Bytes.new(64)
      n, _ = sock.receive(buf)
      String.new(buf[0, n]).should eq "READY=1\nSTATUS=ready"
    ensure
      sock.close
      File.delete?(path)
    end
  end

  it "raises when no one listens there" do
    expect_raises(RuntimeError, /sending to NOTIFY_SOCKET/) do
      systemd.notify("READY=1", File.tempname("mj-notify-none", ".sock"))
    end
  end
end
