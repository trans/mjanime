# The voice service on its own, as bin/mj-arcana loads it: the rest of mj (spec_helper's
# src/lib) has an `Arcana` of its own that MJ::Arcana would shadow.
require "spec"
require "../../src/arcana/voice_service"

private def req(json : String) : JSON::Any
  JSON.parse(json)
end

describe MJ::Arcana::VoiceLanes do
  # ElevenLabs limits v3/v2 and Flash/Turbo separately (measured 2026-10-21), songs apart.
  it "puts each request in the lane of the limit it counts against" do
    lanes = MJ::Arcana::VoiceLanes
    lanes.for(req(%({"tool":"speak","provider":"elevenlabs","model":"eleven_v3"}))).should eq("elevenlabs")
    lanes.for(req(%({"tool":"speak","provider":"elevenlabs"}))).should eq("elevenlabs") # multilingual v2
    lanes.for(req(%({"tool":"speak","provider":"elevenlabs","model":"eleven_flash_v2_5"}))).should eq("elevenlabs-flash")
    lanes.for(req(%({"tool":"speak","provider":"elevenlabs","model":"eleven_turbo_v2_5"}))).should eq("elevenlabs-flash")
    lanes.for(req(%({"tool":"speak","text":"hi"}))).should eq("openai")
    lanes.for(req(%({"tool":"music","prompt":"a jig"}))).should eq("elevenlabs-music")
    lanes.for(req(%({"tool":"voices"}))).should be_nil
  end

  it "sizes the ElevenLabs lanes to the plan, Starter's for a plan it doesn't know" do
    lanes = MJ::Arcana::VoiceLanes
    lanes.limits("pro").should eq({"elevenlabs" => 10, "elevenlabs-flash" => 20, "elevenlabs-music" => 1, "openai" => 6})
    lanes.limits("enterprise").should eq(lanes.limits("starter"))
    lanes.limits(nil)["elevenlabs"].should eq(3)
  end
end

describe "mj:voice's queue" do
  it "answers expired, unbilled, once less than 3 s of the caller's wait is left" do
    service = MJ::Arcana::VoiceService
    sent = Time.utc - 118.seconds
    due = service.deadline(req(%({"tool":"speak"})), sent, MJ::Arcana::VoiceService::SPEAK_WAIT)
    late = service.expired("elevenlabs", sent, due).not_nil!
    late["status"].as_s.should eq("expired")
    late["usd"].as_f.should eq(0.0)

    # the same wait, said longer by the caller, is still worth making
    due = service.deadline(req(%({"tool":"speak","wait_seconds":300})), sent, MJ::Arcana::VoiceService::SPEAK_WAIT)
    service.expired("elevenlabs", sent, due).should be_nil
  end

  it "retries only ElevenLabs being at its limit" do
    service = MJ::Arcana::VoiceService
    at_limit = %({"detail":{"type":"rate_limit_error","code":"concurrent_limit_exceeded"}})
    service.at_limit?(Arcana::AI::APIError.new(429, at_limit, "elevenlabs:tts")).should be_true
    service.at_limit?(Arcana::AI::APIError.new(429, %({"error":"quota_exceeded"}), "elevenlabs:tts")).should be_false
    service.at_limit?(Arcana::AI::APIError.new(400, at_limit, "elevenlabs:tts")).should be_false
  end

  it "tries again while there's time, then gives up as busy" do
    service = MJ::Arcana::VoiceService
    tries = 0
    result = service.with_room(Time.utc + 60.seconds) do
      tries += 1
      raise Arcana::AI::APIError.new(429, "concurrent_limit_exceeded", "elevenlabs:tts") if tries < 2
      "made"
    end
    result.should eq("made")
    tries.should eq(2)

    expect_raises(MJ::Arcana::VoiceService::Busy) do
      service.with_room(Time.utc + 3.seconds) do
        raise Arcana::AI::APIError.new(429, "concurrent_limit_exceeded", "elevenlabs:tts")
      end
    end
  end
end
