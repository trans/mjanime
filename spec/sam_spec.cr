require "spec"
require "../src/engine/sam"

private def picture_id
  MJ::Sam.store_image(IO::Memory.new("picture"))
end

# A helper without torch: says it's ready, then echoes each line, or stops at "die".
private ECHO = <<-PY
  import sys
  print('{"ready": true}', flush=True)
  for line in sys.stdin:
      if "die" in line:
          sys.exit(1)
      print(line.strip(), flush=True)
  PY

describe MJ::Sam do
  it "names a picture by its bytes" do
    picture_id.should eq(picture_id)
    picture_id.should match(MJ::Sam::IMAGE_ID)
    MJ::Sam.store_image(IO::Memory.new("other")).should_not eq(picture_id)
  end

  it "refuses an empty picture or one that's too big" do
    expect_raises(MJ::Sam::BadRequest) { MJ::Sam.store_image(IO::Memory.new) }
    big = IO::Memory.new(Bytes.new(MJ::Sam::MAX_IMAGE + 1))
    expect_raises(MJ::Sam::BadRequest) { MJ::Sam.store_image(big) }
  end

  it "swaps the picture's id for its path, and passes the prompt on" do
    id = picture_id
    req = JSON.parse(MJ::Sam.helper_request({image: id, points: [[1.5, 2.0]], labels: [1]}.to_json))
    File.basename(req["image"].as_s).should eq(id)
    req["points"][0][0].as_f.should eq(1.5)
    req["box"].raw.should be_nil
    box = JSON.parse(MJ::Sam.helper_request({image: id, box: [0, 0, 9, 9]}.to_json))
    box["box"].as_a.size.should eq(4)
    seen = JSON.parse(MJ::Sam.helper_request({image: id, points: [[1, 2]], labels: [1], view: [0, 0, 9, 9]}.to_json))
    seen["view"].as_a.size.should eq(4)
  end

  it "refuses what can't be a prompt" do
    id = picture_id
    bad = [
      "not json",
      {image: "../../etc/passwd", points: [[1, 2]], labels: [1]}.to_json,
      {image: id, points: [[1, 2]], labels: [] of Int32}.to_json,
      {image: id, points: [[1]], labels: [1]}.to_json,
      {image: id, points: [[1, 2]], labels: [2]}.to_json,
      {image: id, points: [[1, 2]], labels: [0]}.to_json, # only "not this"
      {image: id, box: [1, 2, 3]}.to_json,
      {image: id, points: [[1, 2]], labels: [1], view: [1, 2, 3]}.to_json,
      {image: id}.to_json,
      {image: id, points: Array.new(MJ::Sam::MAX_POINTS + 1) { [1, 2] }, labels: Array.new(MJ::Sam::MAX_POINTS + 1) { 1 }}.to_json,
    ]
    bad.each { |b| expect_raises(MJ::Sam::BadRequest) { MJ::Sam.helper_request(b) } }
  end

  it "says when it no longer has the picture, so the page can send it again" do
    expect_raises(MJ::Sam::NoImage) { MJ::Sam.helper_request({image: "0" * 64, points: [[1, 2]], labels: [1]}.to_json) }
  end

  it "keeps one helper, and starts another when that one dies" do
    MJ::Sam.script = ECHO
    MJ::Sam.ask("one").should eq("one")
    MJ::Sam.ask("two").should eq("two")
    expect_raises(MJ::Sam::Failure) { MJ::Sam.ask("die") }
    MJ::Sam.ask("three").should eq("three")
  end

  it "reports a helper that can't start" do
    MJ::Sam.script = %(print('{"error": "no model"}', flush=True))
    MJ::Sam.ask("die") rescue nil # end the helper the last test left running
    expect_raises(MJ::Sam::Failure, "no model") { MJ::Sam.ask("one") }
    MJ::Sam.script = "raise SystemExit(3)"
    expect_raises(MJ::Sam::Failure, "couldn't start") { MJ::Sam.ask("one") }
  end
end
