require "../spec_helper"

describe Minanime::MotionScript do
  it "parses a YAML script" do
    yaml = <<-YAML
      version: 1
      title: "Test"
      settings:
        width: 512
        height: 512
        model: "runware:106@1"
        strength: 0.9
        steps: 20
      scenes:
        - name: "test_scene"
          frames:
            - prompt: "Move hand up slightly"
            - prompt: "Move hand up more"
              strength: 0.8
              steps: 30
    YAML

    script = Minanime::MotionScript.from_yaml(yaml)
    script.title.should eq("Test")
    script.version.should eq(1)
    script.settings.width.should eq(512)
    script.settings.height.should eq(512)
    script.settings.model.should eq("runware:106@1")
    script.settings.strength.should eq(0.9)
    script.settings.steps.should eq(20)
    script.scenes.size.should eq(1)
    script.scenes[0].name.should eq("test_scene")
    frames = script.scenes[0].frames.should_not be_nil
    frames.size.should eq(2)
    frames[0].prompt.should eq("Move hand up slightly")
    frames[0].strength.should be_nil
    frames[1].strength.should eq(0.8)
    frames[1].steps.should eq(30)
    script.total_frames.should eq(2)
  end

  it "uses default settings when not specified" do
    yaml = <<-YAML
      version: 1
      title: "Minimal"
      scenes:
        - name: "s"
          frames:
            - prompt: "test"
    YAML

    script = Minanime::MotionScript.from_yaml(yaml)
    script.settings.width.should eq(512)
    script.settings.height.should eq(512)
    script.settings.strength.should eq(0.6)
    script.settings.steps.should eq(30)
    script.settings.model.should eq("civitai:4384@128713")
  end

  it "counts frames across multiple scenes" do
    yaml = <<-YAML
      version: 1
      title: "Multi"
      scenes:
        - name: "a"
          frames:
            - prompt: "one"
            - prompt: "two"
        - name: "b"
          frames:
            - prompt: "three"
    YAML

    script = Minanime::MotionScript.from_yaml(yaml)
    script.total_frames.should eq(3)
  end
end
