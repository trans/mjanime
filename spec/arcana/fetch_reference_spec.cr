require "spec"
require "http/server"
require "../../src/arcana/fetch_reference"

PNG = Bytes[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]

# A local store stand-in: what a caller's /media/ URL might serve, good and bad.
SERVER = HTTP::Server.new do |ctx|
  case ctx.request.path
  when "/media/ok.png"  then ctx.response.write(PNG)
  when "/media/text"    then ctx.response.print("an internal reply")
  when "/media/to-meta" then ctx.response.redirect("http://169.254.169.254/latest/meta-data/")
  when "/media/to-ok"   then ctx.response.redirect("/media/ok.png")
  when "/media/endless"
    chunk = Bytes.new(1024 * 1024)
    40.times { ctx.response.write(chunk) }
  else
    ctx.response.status_code = 404
  end
end
LOCAL = SERVER.bind_tcp("127.0.0.1", 0)
spawn { SERVER.listen }
Fiber.yield

private def url(path)
  "http://127.0.0.1:#{LOCAL.port}#{path}"
end

describe MJ::Arcana::FetchReference do
  fetch = ->(u : String) { MJ::Arcana::FetchReference.fetch(u) }

  it "fetches an image from a local store, and follows a redirect within it" do
    fetch.call(url("/media/ok.png")).should eq(PNG)
    fetch.call(url("/media/to-ok")).should eq(PNG)
  end

  it "refuses the droplet's metadata service and loopback outside /media/" do
    ["http://169.254.169.254/latest/meta-data/", "http://10.0.0.1/x.png",
     url("/admin"), url("/media/../admin"), url("/media/%2e%2e/admin"),
     "https://127.0.0.1/media/ok.png"].each do |u|
      expect_raises(MJ::Arcana::FetchReference::Error, /not a public address/) { fetch.call(u) }
    end
  end

  it "checks a redirect's destination too" do
    expect_raises(MJ::Arcana::FetchReference::Error, /169\.254\.169\.254.* not a public address/) do
      fetch.call(url("/media/to-meta"))
    end
  end

  it "stops reading at the cap" do
    expect_raises(MJ::Arcana::FetchReference::Error, /over the \d+ cap/) { fetch.call(url("/media/endless")) }
  end

  it "says a reply isn't an image without echoing it" do
    ex = expect_raises(MJ::Arcana::FetchReference::Error, /did not return a PNG/) { fetch.call(url("/media/text")) }
    ex.message.not_nil!.should_not contain("internal reply")
  end

  it "tells public addresses from the rest" do
    public = ->(a : String) { MJ::Arcana::FetchReference.public?(Socket::IPAddress.new(a, 0)) }
    ["1.1.1.1", "104.16.0.1", "2606:4700::1111"].each { |a| public.call(a).should be_true }
    ["127.0.0.1", "10.1.2.3", "172.20.0.1", "192.168.1.1", "169.254.169.254", "100.64.0.1",
     "0.0.0.0", "224.0.0.1", "192.0.2.1", "::1", "fd00::1", "fe80::1", "::ffff:10.0.0.1",
     "64:ff9b::a9fe:a9fe", "2001:db8::1"].each { |a| public.call(a).should be_false }
  end
end
