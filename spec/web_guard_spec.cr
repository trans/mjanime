require "spec"
require "../src/web/guard"

private def req(method, headers = {} of String => String)
  HTTP::Request.new(method, "/soundbox/tts", HTTP::Headers.new.tap { |h| headers.each { |k, v| h[k] = v } })
end

describe MJ::WebGuard do
  it "answers only to this machine's names" do
    MJ::WebGuard.local_host?("localhost:21683", 21683).should be_true
    MJ::WebGuard.local_host?("127.0.0.1:21683", 21683).should be_true
    MJ::WebGuard.local_host?("evil.example:21683", 21683).should be_false # DNS rebinding
    MJ::WebGuard.local_host?("localhost:8080", 21683).should be_false
    MJ::WebGuard.local_host?(nil, 21683).should be_false
  end

  it "refuses another site's posts, and lets its own and scripts through" do
    g = MJ::WebGuard
    g.cross_site?(req("POST", {"Sec-Fetch-Site" => "cross-site", "Origin" => "https://evil.example"}), 21683).should be_true
    g.cross_site?(req("POST", {"Origin" => "https://evil.example"}), 21683).should be_true
    g.cross_site?(req("POST", {"Sec-Fetch-Site" => "same-site"}), 21683).should be_true
    g.cross_site?(req("POST", {"Sec-Fetch-Site" => "same-origin", "Origin" => "http://localhost:21683"}), 21683).should be_false
    g.cross_site?(req("POST"), 21683).should be_false # curl
    g.cross_site?(req("GET", {"Sec-Fetch-Site" => "cross-site"}), 21683).should be_false
  end
end
