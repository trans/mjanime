require "spec"
require "json"
require "yaml"
require "base64"
require "http/client"
require "stumpy_png"
# The slice of mj that mj-arcana.cr pulls in, without starting the services.
require "../../src/config"
require "../../src/api/spend"
require "../../src/api/generator"
require "../../src/api/dimensions"
require "../../src/api/controlnet"
require "../../src/api/runware_client"
require "../../src/engine/canvas_util"
require "../../src/arcana/camera_service"

# Counts the shots it's asked for, and fails each one the way an overloaded pool does.
class OverloadedTransport < MJ::Arcana::Transport
  getter calls = 0

  def name : String
    "runware"
  end

  def edit(references : Array(Bytes), prompt : String, width : Int32, height : Int32,
           model : String, extra : Hash(String, JSON::Any)?, format : String) : MJ::GenerationResult
    @calls += 1
    raise "Runware API error (503): overloaded"
  end
end

describe "mj:camera's wait_seconds" do
  cam = MJ::Arcana::Cameras.find("klein").not_nil!
  shot = ->(wait : Int32) { JSON.parse({tool: "shoot", camera: "klein", prompt: "a cow", wait_seconds: wait}.to_json) }

  it "expires a shot whose turn comes with less than the camera's typical time left, unmade" do
    tx = OverloadedTransport.new
    sent = Time.utc - (60 - cam.seconds + 1).seconds
    r = MJ::Arcana::CameraService.handle_shoot({"runware" => tx.as(MJ::Arcana::Transport)}, shot.call(60), sent)
    r["status"].should eq("expired")
    r["usd"].as_f.should eq(0.0)
    tx.calls.should eq(0)
  end

  it "makes a shot that still has time" do
    tx = OverloadedTransport.new
    r = MJ::Arcana::CameraService.handle_shoot({"runware" => tx.as(MJ::Arcana::Transport)}, shot.call(120), Time.utc)
    r["status"].should eq("overloaded")
    tx.calls.should eq(1)
  end

  it "starts no retry after the caller's deadline" do
    MJ::Retry.in_time?(10.seconds).should be_true
    MJ::Retry.within(Time.utc + 5.seconds) do
      MJ::Retry.in_time?(1.second).should be_true
      MJ::Retry.in_time?(10.seconds).should be_false
    end
    MJ::Retry.in_time?(10.seconds).should be_true
  end
end
