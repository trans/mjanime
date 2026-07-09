require "./lib"

case ARGV[0]?
when "init"
  Minanime::Config.init!
when "serve", nil
  unless Minanime::Config.initialized?
    STDERR.puts "Not a minanime project. Run `minanime init` first."
    exit 1
  end

  Minanime::Config.load!
  Minanime::Database.setup!
  Minanime::Routes.register

  Kemal.config.port = Minanime::Config.port
  Kemal.config.serve_static = {"dir_listing" => false}
  Kemal.run
when "strip"
  # minanime strip <dir> [out.png]
  # <dir> holds ordered source PNGs plus a strip.yml config.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: minanime strip <dir> [out.png]"
    exit 1
  end

  Minanime::Config.load!
  if Minanime::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end

  script_path = File.join(dir, "strip.yml")
  unless File.exists?(script_path)
    STDERR.puts "No strip.yml in #{dir}. See examples/strip.yml for the format."
    exit 1
  end

  script = Minanime::StripScript.from_yaml(File.read(script_path))
  out_path = ARGV[2]? || File.join(dir, "strip.png")

  client = Minanime::RunwareClient.new(Minanime::Config.runware_api_key)
  builder = Minanime::StripBuilder.new(client)
  builder.build(dir, script, out_path) { |msg| STDERR.puts "[strip] #{msg}" }
when "bed"
  # minanime bed <dir> [strength] — <dir> holds template.png + bed.yml, writes bed.png.
  # Stage 1 of template-guided generation: rudimentary sketch -> plain structural master.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: minanime bed <dir> [strength]"
    exit 1
  end
  Minanime::Config.load!
  if Minanime::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  template = File.join(dir, "template.png")
  spec_path = File.join(dir, "bed.yml")
  unless File.exists?(template) && File.exists?(spec_path)
    STDERR.puts "Need #{template} and #{spec_path}. See examples/bed/ for the format."
    exit 1
  end
  spec = Minanime::BedSpec.from_yaml(File.read(spec_path))
  spec.strength = ARGV[2].to_f if ARGV[2]?   # optional strength override for quick sweeps
  client = Minanime::RunwareClient.new(Minanime::Config.runware_api_key)
  STDERR.puts "[bed] #{template} -> bed.png (model=#{spec.model} strength=#{spec.strength})"
  result = Minanime::Bed.generate(client, template, spec)
  bed_path = File.join(dir, "bed.png")
  File.write(bed_path, result.image_data)
  STDERR.puts "[bed] wrote #{bed_path}"
when "prop"
  # minanime prop <dir> — <dir> holds template.png + prop.yml, writes render.png + prop.png.
  # The prop machine: rough template -> Nano render on a solid bg -> keyed transparent prop.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: minanime prop <dir>"
    exit 1
  end
  Minanime::Config.load!
  if Minanime::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  template = File.join(dir, "template.png")
  spec_path = File.join(dir, "prop.yml")
  unless File.exists?(template) && File.exists?(spec_path)
    STDERR.puts "Need #{template} and #{spec_path}. See examples/prop/ for the format."
    exit 1
  end
  spec = Minanime::PropSpec.from_yaml(File.read(spec_path))
  client = Minanime::RunwareClient.new(Minanime::Config.runware_api_key)
  STDERR.puts "[prop] #{template} -> prop.png (model=#{spec.model} bg=#{spec.background} " \
    "key=#{spec.key_low}..#{spec.key_high} blur=#{spec.edge_blur})"
  result = Minanime::Prop.generate(client, template, spec)
  render_path = File.join(dir, "render.png")
  prop_path = File.join(dir, "prop.png")
  Minanime::CanvasUtil.write_png_file(result.render, render_path)
  Minanime::CanvasUtil.write_png_file(result.prop, prop_path)
  STDERR.puts "[prop] wrote #{render_path} and #{prop_path}"
when "version", "--version", "-v"
  puts "minanime #{Minanime::VERSION}"
else
  STDERR.puts "Usage: minanime [init|serve|strip|bed|prop|version]"
  exit 1
end
