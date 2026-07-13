require "./lib"

case ARGV[0]?
when "init"
  MJ::Config.init!
when "serve", nil
  unless MJ::Config.initialized?
    STDERR.puts "Not a mj project. Run `mj init` first."
    exit 1
  end

  MJ::Config.load!
  MJ::Database.setup!
  MJ::Routes.register

  # Join the Arcana bus alongside the web server (opt out with MJ_BUS=0).
  MJ::BusService.start_background unless ENV["MJ_BUS"]? == "0"

  Kemal.config.port = MJ::Config.port
  Kemal.config.serve_static = {"dir_listing" => false}
  Kemal.run
when "strip"
  # mj strip <dir> [out.png]
  # <dir> holds ordered source PNGs plus a strip.yml config.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: mj strip <dir> [out.png]"
    exit 1
  end

  MJ::Config.load!
  if MJ::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end

  script_path = File.join(dir, "strip.yml")
  unless File.exists?(script_path)
    STDERR.puts "No strip.yml in #{dir}. See examples/strip.yml for the format."
    exit 1
  end

  script = MJ::StripScript.from_yaml(File.read(script_path))
  out_path = ARGV[2]? || File.join(dir, "strip.png")

  client = MJ::RunwareClient.new(MJ::Config.runware_api_key)
  builder = MJ::StripBuilder.new(client)
  builder.build(dir, script, out_path) { |msg| STDERR.puts "[strip] #{msg}" }
when "bed"
  # mj bed <dir> [strength] — <dir> holds template.png + bed.yml, writes bed.png.
  # Stage 1 of template-guided generation: rudimentary sketch -> plain structural master.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: mj bed <dir> [strength]"
    exit 1
  end
  MJ::Config.load!
  if MJ::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  template = File.join(dir, "template.png")
  spec_path = File.join(dir, "bed.yml")
  unless File.exists?(template) && File.exists?(spec_path)
    STDERR.puts "Need #{template} and #{spec_path}. See examples/bed/ for the format."
    exit 1
  end
  spec = MJ::BedSpec.from_yaml(File.read(spec_path))
  spec.strength = ARGV[2].to_f if ARGV[2]?   # optional strength override for quick sweeps
  client = MJ::RunwareClient.new(MJ::Config.runware_api_key)
  STDERR.puts "[bed] #{template} -> bed.png (model=#{spec.model} strength=#{spec.strength})"
  result = MJ::Bed.generate(client, template, spec)
  bed_path = File.join(dir, "bed.png")
  File.write(bed_path, result.image_data)
  STDERR.puts "[bed] wrote #{bed_path}"
when "prop"
  # mj prop <dir> — <dir> holds template.png + prop.yml, writes render.png + prop.png.
  # The prop machine: rough template -> Nano render on a solid bg -> keyed transparent prop.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: mj prop <dir>"
    exit 1
  end
  MJ::Config.load!
  if MJ::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  template = File.join(dir, "template.png")
  spec_path = File.join(dir, "prop.yml")
  unless File.exists?(template) && File.exists?(spec_path)
    STDERR.puts "Need #{template} and #{spec_path}. See examples/prop/ for the format."
    exit 1
  end
  spec = MJ::PropSpec.from_yaml(File.read(spec_path))
  client = MJ::RunwareClient.new(MJ::Config.runware_api_key)
  STDERR.puts "[prop] #{template} -> prop.png (model=#{spec.model} bg=#{spec.background} " \
    "key=#{spec.key_low}..#{spec.key_high} blur=#{spec.edge_blur})"
  result = MJ::Prop.generate(client, template, spec)
  render_path = File.join(dir, "render.png")
  prop_path = File.join(dir, "prop.png")
  MJ::CanvasUtil.write_png_file(result.render, render_path)
  MJ::CanvasUtil.write_png_file(result.prop, prop_path)
  STDERR.puts "[prop] wrote #{render_path} and #{prop_path}"
when "pixelize"
  # mj pixelize <dir> — <dir> holds image.png + pixel.yml, writes redraw.png + pixel.png.
  # AI pixel-art restyle (8-bit/16-bit) via Nano Banana 2, optional transparency + snap.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: mj pixelize <dir>"
    exit 1
  end
  MJ::Config.load!
  if MJ::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  image = File.join(dir, "image.png")
  spec_path = File.join(dir, "pixel.yml")
  unless File.exists?(image) && File.exists?(spec_path)
    STDERR.puts "Need #{image} and #{spec_path}. See examples/pixel/ for the format."
    exit 1
  end
  spec = MJ::PixelSpec.from_yaml(File.read(spec_path))
  client = MJ::RunwareClient.new(MJ::Config.runware_api_key)
  STDERR.puts "[pixelize] #{image} -> pixel.png (style=#{spec.style} model=#{spec.model} " \
    "snap=#{spec.snap} bg=#{spec.background})"
  redraw = MJ::Pixelize.redraw(client, File.read(image).to_slice, spec)
  redraw_path = File.join(dir, "redraw.png")
  File.write(redraw_path, redraw)
  final = MJ::Pixelize.finish(redraw, spec)
  pixel_path = File.join(dir, "pixel.png")
  MJ::CanvasUtil.write_png_file(final, pixel_path)
  STDERR.puts "[pixelize] wrote #{redraw_path} and #{pixel_path}"
when "bus"
  # mj bus — join the Arcana bus and serve the image tools (pixelize/prop/bed).
  MJ::BusService.run
when "version", "--version", "-v"
  puts "mj #{MJ::VERSION}"
else
  STDERR.puts "Usage: mj [init|serve|strip|bed|prop|pixelize|bus|version]"
  exit 1
end
