require "../spec_helper"

describe MJ::RunwareClient do
  # This spec makes a real API call.
  # Run with: RUNWARE_API_KEY=your_key crystal spec spec/api/runware_client_spec.cr
  #
  # Needs a reference image at data/cuts/*/reference.png or provide
  # TEST_IMAGE=/path/to/image.png

  it "generates an image from a seed image" do
    api_key = ENV["RUNWARE_API_KEY"]? || ""
    pending! "RUNWARE_API_KEY not set" if api_key.empty?

    # Find a test image
    ref_path = ENV["TEST_IMAGE"]?
    unless ref_path
      candidates = Dir.glob("data/cuts/*/reference.png")
      ref_path = candidates.first? if candidates.size > 0
    end
    pending! "No test image found (set TEST_IMAGE=/path/to/image.png)" unless ref_path
    pending! "Test image not found: #{ref_path}" unless File.exists?(ref_path.not_nil!)

    client = MJ::RunwareClient.new(api_key)
    request = MJ::GenerationRequest.new(
      prompt: "A slight smile appears on the face",
      seed_image: ref_path.not_nil!,
      width: 1024,
      height: 1024,
      steps: 10,
      strength: 0.95
    )

    puts "Sending request to Runware API..."
    puts "Image: #{ref_path}"
    start = Time.instant
    result = client.generate(request)
    elapsed = Time.instant - start

    puts "Response in #{elapsed.total_seconds.round(2)}s"
    puts "Image size: #{result.image_data.size} bytes"
    puts "Image UUID: #{result.image_uuid}"

    result.image_data.size.should be > 0
    result.image_uuid.should_not be_nil
  end
end
