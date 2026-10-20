require "../spec_helper"

describe "MJ.snap_dimensions" do
  # Runware takes FLUX.1 sizes from 128 to 2048 in steps of 64, and refuses the rest with a
  # 400 (schnell and dev, 2026-10-20).
  it "rounds FLUX.1 sizes to multiples of 64" do
    # the old list's widest pair, halfway between steps on both sides: halves round up
    MJ.snap_dimensions(1568, 672, "runware:100@1").should eq({1600, 704})
    MJ.snap_dimensions(1550, 650, "runware:100@1").should eq({1536, 640})
    MJ.snap_dimensions(1344, 768, "runware:101@1").should eq({1344, 768})
    MJ.snap_dimensions(1000, 1000, "runware:100@1").should eq({1024, 1024})
  end

  it "keeps FLUX.1 sizes within 128 to 2048" do
    MJ.snap_dimensions(50, 4000, "runware:100@1").should eq({128, 2048})
  end

  it "rounds other models to multiples of 16" do
    MJ.snap_dimensions(1000, 1000, "runware:400@1").should eq({1008, 1008})
  end
end
