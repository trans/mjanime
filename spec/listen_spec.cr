require "./spec_helper"

# A steady vowel-like tone with a little noise: 2 s at MJ::Listen::SR, peaking near 0.6.
private def tone(seconds = 2.0) : Array(Float32)
  rng = Random.new(7)
  Array(Float32).new((seconds * MJ::Listen::SR).to_i) do |i|
    t = i / MJ::Listen::SR.to_f
    (0.45 * Math.sin(2 * Math::PI * 140 * t) + 0.15 * Math.sin(2 * Math::PI * 420 * t) + 0.005 * (rng.rand - 0.5)).to_f32
  end
end

private def kinds(x : Array(Float32)) : Array({String, Float64})
  MJ::Listen::Glitch.find(x).map { |f| {f.kind, f.time.round(2)} }
end

describe MJ::Listen::Glitch do
  it "finds nothing in a clean tone" do
    kinds(tone).should be_empty
  end

  it "finds a 2 ms click" do
    x = tone
    i = MJ::Listen::SR
    48.times { |k| x[i + k] += (k.even? ? 0.7 : -0.7).to_f32 }
    kinds(x).should eq([{"click", 1.0}])
  end

  it "finds a hard cut where the waveform jumps" do
    x = tone
    i = MJ::Listen::SR
    # splice a peak straight onto a trough, a step of about 1.0
    period = MJ::Listen::SR // 140 + 1
    a = i + (0...period).max_by { |k| x[i + k] }
    b = i + period + (0...period).min_by { |k| x[i + period + k] }
    x = x[0..a] + x[b..]
    kinds(x).should eq([{"cut", (a / MJ::Listen::SR.to_f).round(2)}])
  end

  it "finds a dropout the voice falls into from full volume" do
    x = tone
    i = MJ::Listen::SR
    (i...i + MJ::Listen::SR // 4).each { |k| x[k] = 0.0_f32 }
    kinds(x).should eq([{"dropout", 1.0}])
  end

  it "doesn't count a pause the voice fades into" do
    x = tone
    i = MJ::Listen::SR
    fade = MJ::Listen::SR // 10
    fade.times { |k| x[i - fade + k] *= (1.0 - k / fade.to_f).to_f32 }
    (i...i + MJ::Listen::SR // 4).each { |k| x[k] = 0.0_f32 }
    kinds(x).should be_empty
  end

  it "finds clipping" do
    x = tone.map { |v| (v * 4).clamp(-0.5, 0.5).to_f32 }
    MJ::Listen::Glitch.find(x).map(&.kind).uniq.should eq(["clipping"])
  end
end

describe MJ::Listen do
  it "takes the audio tags out of a script" do
    MJ::Listen.tokens("[strong Scottish accent] Up a tree. [chuckles] Don't ask!").map(&.text)
      .should eq(%w(up a tree dont ask))
  end

  it "treats one letter's difference in a long word as the same word, not in a short one" do
    MJ::Listen.same_word?("jewelled", "jeweled").should be_true
    MJ::Listen.same_word?("roll", "roar").should be_false
  end

  it "finds where the heard words leave the script" do
    script = MJ::Listen.tokens("Fate. Roll the dice, keep the good ones.")
    heard = MJ::Listen.tokens("Fate, roar the dice, keep the good ones")
    d = MJ::Listen.diff(script, heard)
    d.map { |x| {x.script.map(&.text), x.heard.map(&.text)} }.should eq([{ %w(roll), %w(roar) }])
  end

  it "says where both listeners heard the same difference, and where only one did" do
    script = MJ::Listen.tokens("Lots of doors. Like a hotel, but every room's a decision.")
    whisper = MJ::Listen.tokens("Lots of doors. What's a hotel? But every room's a decision.")
    gemini = MJ::Listen.tokens("lots of doors, what's a hotel, but every room is a decision")
    notes = MJ::Listen.notes(script, whisper, gemini)
    notes.map { |n| {n.script, n.whisper, n.gemini, n.both?} }.should eq([
      {"Like", "What's", "what's", true},
      {"room's", nil, "room is", false},
    ])
  end

  it "reads the script from the .txt beside a take" do
    dir = File.tempname("mj_listen")
    Dir.mkdir(dir)
    File.write(File.join(dir, "line.txt"), "[sings] Hello there\n")
    MJ::Listen.script_for(File.join(dir, "line.mp3"), nil).should eq({"[sings] Hello there", "line.txt"})
    MJ::Listen.script_for(File.join(dir, "other.mp3"), nil).should be_nil
    MJ::Listen.script_for(File.join(dir, "line.mp3"), "given").should eq({"given", "the given script"})
  ensure
    FileUtils.rm_rf(dir) if dir
  end
end
