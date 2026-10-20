require "./spec_helper"
require "yaml"

describe MJ do
  # The version is written twice, in shard.yml and in src/lib.cr; this fails when one is
  # bumped without the other. (It named "0.1.0" until 2026-10-20, long after 0.11.0.)
  it "has the version shard.yml gives" do
    shard = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))
    MJ::VERSION.should eq(shard["version"].as_s)
  end
end
