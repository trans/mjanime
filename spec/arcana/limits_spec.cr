require "spec"
require "../../src/arcana/limits"

describe MJ::Arcana::Limits do
  limits = MJ::Arcana::Limits

  it "passes anything a game would send, and refuses past the limits" do
    limits.text!(JSON.parse({text: "a" * 10_000, instructions: "calm"}.to_json), "text", "instructions")
    expect_raises(Exception, /instructions is 10001 characters.*Nothing was billed/) do
      limits.text!(JSON.parse({text: "hi", instructions: "a" * 10_001}.to_json), "text", "instructions")
    end
  end

  it "bounds wait_seconds" do
    limits.wait!(JSON.parse(%({"wait_seconds":3600})))
    limits.wait!(JSON.parse(%({})))
    expect_raises(Exception, /wait_seconds/) { limits.wait!(JSON.parse(%({"wait_seconds":3601}))) }
  end

  it "adds up a plan's sections, or takes a prompt's length" do
    plan = {composition_plan: {sections: [{duration_ms: 300_000}, {duration_ms: 300_000}]}}
    limits.song!(JSON.parse(plan.to_json))
    plan[:composition_plan][:sections] << {duration_ms: 1}
    expect_raises(Exception, /600 s/) { limits.song!(JSON.parse(plan.to_json)) }
    expect_raises(Exception, /song/) { limits.song!(JSON.parse(%({"prompt":"x","music_length_ms":600001}))) }
    limits.song!(JSON.parse(%({"prompt":"x"})))
  end

  it "counts references before any is fetched" do
    limits.references!(JSON.parse({references_url: ["http://x/"] * 16}.to_json))
    expect_raises(Exception, /17 references/) do
      limits.references!(JSON.parse({references_url: ["http://x/"] * 17}.to_json))
    end
    expect_raises(Exception, /over 32 MB/) do
      limits.references!(JSON.parse({reference_base64: "A" * (33 * 1024 * 1024 // 3 * 4)}.to_json))
    end
  end
end
