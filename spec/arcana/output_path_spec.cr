require "spec"
require "file_utils"
require "../../src/arcana/output_path"

describe MJ::Arcana::OutputPath do
  out = MJ::Arcana::OutputPath
  home = File.tempname("mj-out-spec")
  # Scoped to this describe: Spec.before_each would point every spec in the suite at
  # `home`, and a live spec's ledger row went there and was deleted (2026-10-22).
  real = ENV["XDG_DATA_HOME"]?
  before_each { Dir.mkdir_p(home); ENV["XDG_DATA_HOME"] = home }
  after_each { FileUtils.rm_rf(home); ENV["XDG_DATA_HOME"] = real }

  it "writes a new file inside the out directory, and never over one" do
    full = out.check!("take.mp3")
    full.should eq(File.join(home, "mj", "out", "take.mp3"))
    out.write(full, "one".to_slice)
    File.read(full).should eq("one")
    expect_raises(Exception, /already exists/) { out.check!("take.mp3") }
    expect_raises(Exception, /not overwritten/) { out.write(full, "two".to_slice) }
    File.read(full).should eq("one")
  end

  it "makes subdirectories, and takes an absolute path inside" do
    out.check!("bard/a1.mp3").should eq(File.join(home, "mj", "out", "bard", "a1.mp3"))
    out.check!(File.join(home, "mj", "out", "b1.mp3")).should end_with("/out/b1.mp3")
  end

  it "refuses the ledger, other paths and symlinks" do
    File.write(File.join(home, "mj", "spend.jsonl"), "") rescue nil
    ["../spend.jsonl", File.join(home, "mj", "spend.jsonl"), "/tmp/x.mp3"].each do |p|
      expect_raises(Exception, /outside/) { out.check!(p) }
    end
    Dir.mkdir_p(File.join(home, "mj", "out"))
    File.symlink("/tmp", File.join(home, "mj", "out", "link"))
    expect_raises(Exception, /goes through/) { out.check!("link/x.mp3") }
    File.symlink("/tmp/nowhere", File.join(home, "mj", "out", "dangling.mp3"))
    expect_raises(Exception, /already exists/) { out.check!("dangling.mp3") }
  end
end
