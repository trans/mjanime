require "./spec_helper"
require "file_utils"

# A short mono 16-bit WAV of a tone; `pitch` makes each file's bytes differ.
private def wav(path : String, pitch = 220.0, seconds = 0.3) : String
  rate = 24_000
  n = (seconds * rate).to_i
  File.open(path, "wb") do |f|
    le = IO::ByteFormat::LittleEndian
    f << "RIFF"
    f.write_bytes((36 + n * 2).to_u32, le)
    f << "WAVEfmt "
    f.write_bytes(16_u32, le)
    f.write_bytes(1_u16, le)
    f.write_bytes(1_u16, le)
    f.write_bytes(rate.to_u32, le)
    f.write_bytes((rate * 2).to_u32, le)
    f.write_bytes(2_u16, le)
    f.write_bytes(16_u16, le)
    f << "data"
    f.write_bytes((n * 2).to_u32, le)
    n.times { |i| f.write_bytes((8000 * Math.sin(2 * Math::PI * pitch * i / rate)).to_i16, le) }
  end
  path
end

private def entries(json : String) : Array(MJ::Dungeon::Entry)
  Array(MJ::Dungeon::Entry).from_json(json)
end

private def with_store(&)
  dir = File.tempname("mj_dungeon")
  Dir.mkdir(dir)
  old = ENV["MJ_DUNGEON_DIR"]?
  ENV["MJ_DUNGEON_DIR"] = File.join(dir, "store")
  begin
    MJ::Dungeon.open { |db| yield db, dir }
  ensure
    old ? (ENV["MJ_DUNGEON_DIR"] = old) : ENV.delete("MJ_DUNGEON_DIR")
    FileUtils.rm_rf(dir)
  end
end

describe MJ::Dungeon do
  it "files a sound waiting on Thomas, with its events as a track" do
    with_store do |db, dir|
      roll = wav(File.join(dir, "roll-1.wav"))
      File.write(File.join(dir, "roll-1.events.json"), %({"length": 0.3, "shakes": [0.1, 0.15], "first_knock": 0.2, "end": 0.25}))
      ids = MJ::Dungeon.add(db, entries(%([{"type": "effect", "file": "#{roll}", "traits": {"piece": "dice-roll", "sound": "roll"},
        "description": "A die shaken and thrown", "events": "#{dir}/roll-1.events.json", "why": "not heard yet"}])))
      waiting = MJ::Dungeon.waiting(db)
      waiting.map(&.id).should eq(ids)
      it = waiting.first
      {it.take, it.piece, it.why, it.words, it.key}.should eq({"roll-1", "dice-roll", "not heard yet", "A die shaken and thrown", "effect.dice-roll.roll"})
      db.track(it.id, "events").not_nil!.cues.map { |c| {c.start_ms, c.value} }
        .should eq([{100, "shake"}, {150, "shake"}, {200, "first-knock"}, {250, "end"}])
    end
  end

  it "records Thomas's answer: yes keeps it, no takes it out of play" do
    with_store do |db, dir|
      a = wav(File.join(dir, "a.wav"), 220.0)
      b = wav(File.join(dir, "b.wav"), 330.0)
      ids = MJ::Dungeon.add(db, entries(%([
        {"type": "effect", "file": "#{a}", "traits": {"piece": "p", "sound": "a"}, "why": "listen"},
        {"type": "effect", "file": "#{b}", "traits": {"piece": "p", "sound": "b"}, "why": "listen"}])))
      MJ::Dungeon.heard(db, ids[0], true, "they are fine")
      MJ::Dungeon.heard(db, ids[1], false, "elf")
      MJ::Dungeon.waiting(db).should be_empty
      MJ::Dungeon.answered(db).map { |i| {i.take.to_s, i.answer.to_s, i.note.to_s} }.sort
        .should eq([{"a", "yes", "they are fine"}, {"b", "no", "elf"}])
      db.get_by_id(ids[0], touch: false).not_nil!.rating.should eq(1)
      db.get_by_id(ids[1], touch: false).not_nil!.flagged.should be_true
    end
  end

  it "files the same take again as the same asset, without asking again once answered" do
    with_store do |db, dir|
      a = wav(File.join(dir, "a.wav"))
      manifest = entries(%([{"type": "effect", "file": "#{a}", "traits": {"piece": "p", "sound": "a"}, "why": "listen"}]))
      first = MJ::Dungeon.add(db, manifest)
      MJ::Dungeon.heard(db, first[0], true)
      MJ::Dungeon.add(db, manifest).should eq(first)
      MJ::Dungeon.waiting(db).should be_empty
    end
  end

  it "takes a take's words from the .txt beside it, and its mouth from Rhubarb's JSON" do
    with_store do |db, dir|
      take = wav(File.join(dir, "tour-u-1-gerald.wav"))
      File.write(File.join(dir, "tour-u-1-gerald.txt"), "[strong Scottish accent] This is actual Zork.\n")
      File.write(File.join(dir, "tour-u-1-gerald.json"), %({"mouthCues": [{"start": 0.0, "end": 0.1, "value": "X"}, {"start": 0.1, "end": 0.3, "value": "B"}]}))
      ids = MJ::Dungeon.add(db, entries(%([{"type": "speech", "file": "#{take}",
        "traits": {"piece": "landing-tour", "line": "u-1", "subtype": "spoken", "voice": "gerald", "accent": ""},
        "mouth": "#{dir}/tour-u-1-gerald.json", "why": "listen",
        "recipe": {"form": "speech", "settings": {"model": "eleven_v3"}, "prompt": "This is actual Zork.", "cost": 0.0027}}])),
        listen: false)
      it = MJ::Dungeon.get(db, ids[0]).not_nil!
      it.words.should eq("This is actual Zork.")
      it.key.should eq("speech.landing-tour.u-1.spoken.gerald.")
      it.listen.should be_nil
      db.track(ids[0], "mouth").not_nil!.cues.map(&.value).should eq(%w(X B))
      db.recipe(ids[0]).not_nil!.prompt.should eq("This is actual Zork.")
    end
  end

  it "puts the listen checks in a track, each glitch and word note at its time" do
    r = MJ::Listen::Result.new("t.mp3", 6.6, [MJ::Listen::Finding.new(4.5, "click", "a 2 ms burst")], "Like a hotel", "t.txt",
      ["Whisper", "Gemini"], [MJ::Listen::WordNote.new("Like", "What's", "what's", 3.3)], nil, nil, nil, nil, nil, nil, nil)
    MJ::Dungeon.listen_cues(r).map { |c| {c.start_ms, c.value} }.should eq([
      {3300, %("Like" at 3.3 s: Whisper heard "What's", Gemini heard "what's" (both: worth a listen))},
      {4500, "4.5 s, click: a 2 ms burst"},
    ])
    MJ::Dungeon.listen_tool(r).should eq("mj listen #{MJ::VERSION} (glitches, Whisper small.en, #{MJ::Listen::WORDS_MODEL})")
  end

  it "removes an asset" do
    with_store do |db, dir|
      ids = MJ::Dungeon.add(db, entries(%([{"type": "effect", "file": "#{wav(File.join(dir, "a.wav"))}",
        "traits": {"piece": "p", "sound": "a"}, "why": "listen"}])))
      MJ::Dungeon.remove(db, ids[0])
      MJ::Dungeon.everything(db).should be_empty
    end
  end
end
