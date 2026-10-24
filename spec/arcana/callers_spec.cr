require "spec"
require "../../src/arcana/callers"

private def env(from, verified)
  Arcana::Envelope.new(from: from, to: "mj:voice", verified: verified)
end

describe MJ::Arcana::Callers do
  callers = MJ::Arcana::Callers

  it "serves anyone, verified or not, when there is no list" do
    callers.check!(env("@mj", false), nil)
    callers.check!(env("owl", false), nil)
  end

  it "serves a listed caller only when the bus verified it" do
    list = ["overlore"]
    callers.check!(env("overlore", true), list)
    expect_raises(Exception, /didn't verify.*Nothing was billed/) { callers.check!(env("overlore", false), list) }
    expect_raises(Exception, /"@mj" isn't a caller/) { callers.check!(env("@mj", true), list) }
  end

  it "reads a list split on commas or spaces, and none from an empty one" do
    callers.parse("overlore, @overlore  @mj").should eq ["overlore", "@overlore", "@mj"]
    callers.parse("").should be_nil
    callers.parse(" , ").should be_nil
    callers.parse(nil).should be_nil
  end
end
