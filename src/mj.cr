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
  MJ::Shadowbox.register

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
when "base"
  # mj base <dir> [strength] — <dir> holds template.png + base.yml, writes base.png.
  # Stage 1 of template-guided generation: rudimentary sketch -> plain structural master.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: mj base <dir> [strength]"
    exit 1
  end
  MJ::Config.load!
  if MJ::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  template = File.join(dir, "template.png")
  spec_path = File.join(dir, "base.yml")
  unless File.exists?(template) && File.exists?(spec_path)
    STDERR.puts "Need #{template} and #{spec_path}. See examples/base/ for the format."
    exit 1
  end
  spec = MJ::BaseSpec.from_yaml(File.read(spec_path))
  spec.strength = ARGV[2].to_f if ARGV[2]?   # optional strength override for quick sweeps
  client = MJ::RunwareClient.new(MJ::Config.runware_api_key)
  STDERR.puts "[base] #{template} -> base.png (model=#{spec.model} strength=#{spec.strength})"
  result = MJ::Base.generate(client, template, spec)
  base_path = File.join(dir, "base.png")
  File.write(base_path, result.image_data)
  STDERR.puts "[base] wrote #{base_path}"
when "prop"
  # mj prop <dir> — <dir> holds template.png + prop.yml, writes render.png + prop.png.
  # The prop machine: rough template -> Nano render on a solid bg -> keyed transparent prop.
  # <name> resolves inside the prop library root (Config.props_dir); a path with a
  # separator is treated as an explicit one-off directory.
  name_or_path = ARGV[1]?
  unless name_or_path
    STDERR.puts "Usage: mj prop <name|dir> [--rekey]   (props live in #{MJ::Config.default_props_dir})"
    exit 1
  end
  MJ::Config.load! # resolves props_dir (and api keys)
  # --rekey: re-run only the keying step on the existing render.png (no API call).
  # Use it to tune key_low/key_high/blur/despill/defringe/bleed against a render you like.
  rekey = ARGV.includes?("--rekey")
  dir = MJ::PropLibrary.resolve(name_or_path)
  spec_path = File.join(dir, "prop.yml")
  render_path = File.join(dir, "render.png")
  prop_path = File.join(dir, "prop.png")
  unless File.exists?(spec_path)
    STDERR.puts "Need #{spec_path}. See examples/prop/ for the format."
    exit 1
  end
  spec = MJ::PropSpec.from_yaml(File.read(spec_path))

  if rekey
    unless File.exists?(render_path)
      STDERR.puts "--rekey needs an existing #{render_path} (run without --rekey first)."
      exit 1
    end
    STDERR.puts "[prop] rekey #{render_path} -> prop.png (bg=#{spec.background} " \
      "key=#{spec.key_low}..#{spec.key_high} blur=#{spec.edge_blur})"
    render = MJ::CanvasUtil.from_png_file(render_path)
    prop = MJ::Prop.key_out(render, spec)
    MJ::CanvasUtil.write_png_file(prop, prop_path)
    MJ::PropLibrary.record(dir, spec)
    STDERR.puts "[prop] wrote #{prop_path}"
    exit 0
  end

  if MJ::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  template = File.join(dir, "template.png")
  unless File.exists?(template) && File.exists?(spec_path)
    STDERR.puts "Need #{template} and #{spec_path}. See examples/prop/ for the format."
    exit 1
  end
  client = MJ::RunwareClient.new(MJ::Config.runware_api_key)
  STDERR.puts "[prop] #{template} -> prop.png (model=#{spec.model} bg=#{spec.background} " \
    "key=#{spec.key_low}..#{spec.key_high} blur=#{spec.edge_blur})"
  result = MJ::Prop.generate(client, template, spec)
  MJ::CanvasUtil.write_png_file(result.render, render_path)
  MJ::CanvasUtil.write_png_file(result.prop, prop_path)
  MJ::PropLibrary.record(dir, spec)
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
when "decorate"
  # mj decorate <dir> — <dir> holds image.png (the master) + decorate.yml, optional style.png.
  # Stage 2: redraw the master decorated in a style/theme. Writes decorated.png.
  dir = ARGV[1]?
  unless dir
    STDERR.puts "Usage: mj decorate <dir>"
    exit 1
  end
  MJ::Config.load!
  if MJ::Config.runware_api_key.empty?
    STDERR.puts "RUNWARE_API_KEY not set."
    exit 1
  end
  image = File.join(dir, "image.png")
  spec_path = File.join(dir, "decorate.yml")
  unless File.exists?(image) && File.exists?(spec_path)
    STDERR.puts "Need #{image} and #{spec_path}. See examples/decorate/ for the format."
    exit 1
  end
  spec = MJ::DecorateSpec.from_yaml(File.read(spec_path))
  style_path = File.join(dir, "style.png")
  style = File.exists?(style_path) ? File.read(style_path).to_slice : nil
  client = MJ::RunwareClient.new(MJ::Config.runware_api_key)
  STDERR.puts "[decorate] #{image}#{style ? " + style.png" : ""} -> decorated.png (model=#{spec.model})"
  bytes = MJ::Decorate.generate(client, File.read(image).to_slice, spec, style)
  out_path = File.join(dir, "decorated.png")
  File.write(out_path, bytes)
  STDERR.puts "[decorate] wrote #{out_path}"
when "sfx"
  # mj sfx <input.wav|mp3> [out.sfx.json] [preview.wav]
  # Fit a procedural Web Audio SFX recipe from a reference sound (no API needed).
  input = ARGV[1]?
  unless input
    STDERR.puts "Usage: mj sfx <input.wav|mp3> [out.sfx.json] [preview.wav]"
    exit 1
  end
  preview = ARGV[3]?
  recipe = MJ::Sfx.fit(input, preview)
  out_path = ARGV[2]? || input.sub(/\.[^.]+$/, "") + ".sfx.json"
  File.write(out_path, recipe.to_pretty_json)
  STDERR.puts "[sfx] #{input} -> #{out_path}#{preview ? " (+ #{preview})" : ""}"
when "bus"
  # mj bus — join the Arcana bus and serve the tools (pixelize/prop/base/decorate/sfx).
  MJ::BusService.run
when "webp"
  # mj webp [<prop-name>] [--quality N] — transcode library deliverables to .webp (kept next to the
  # PNG). Shadowbox serves the .webp when present. No name = every prop + every backdrop.
  MJ::Config.load!
  unless MJ::Webp.available?
    STDERR.puts "mj webp needs ImageMagick (magick/convert) on PATH."
    exit 1
  end
  quality = 82
  ARGV.each_with_index { |a, i| quality = (ARGV[i + 1]?.try(&.to_i) || quality) if a == "--quality" }
  only = ARGV[1]?.try { |x| x.starts_with?("--") ? nil : x }

  jobs = [] of {String, String, String} # {label, src.png, dst.webp}
  if only
    p = File.join(MJ::Config.props_dir, only, "prop.png")
    jobs << {"prop #{only}", p, File.join(MJ::Config.props_dir, only, "prop.webp")} if File.file?(p)
    STDERR.puts "No prop.png for '#{only}'." if jobs.empty?
  else
    if Dir.exists?(MJ::Config.props_dir)
      Dir.each_child(MJ::Config.props_dir) do |n|
        p = File.join(MJ::Config.props_dir, n, "prop.png")
        jobs << {"prop #{n}", p, File.join(MJ::Config.props_dir, n, "prop.webp")} if File.file?(p)
      end
    end
    if Dir.exists?(MJ::Config.backdrops_dir)
      Dir.each_child(MJ::Config.backdrops_dir) do |f|
        next unless f.downcase.ends_with?(".png")
        src = File.join(MJ::Config.backdrops_dir, f)
        jobs << {"backdrop #{f}", src, src.sub(/\.png\z/i, ".webp")}
      end
    end
  end

  before = 0_i64
  after = 0_i64
  ok = 0
  jobs.sort_by! { |j| j[0] }.each do |label, src, dst|
    if MJ::Webp.encode(src, dst, quality)
      psz = File.size(src); wsz = File.size(dst)
      before += psz; after += wsz; ok += 1
      STDERR.puts "[webp] #{label}: #{psz // 1024}K -> #{wsz // 1024}K (#{(100 - wsz * 100 // psz)}% smaller)"
    else
      STDERR.puts "[webp] #{label}: FAILED"
    end
  end
  if ok > 0
    STDERR.puts "[webp] #{ok} file(s) q=#{quality}: #{before // 1024}K -> #{after // 1024}K " \
      "(saved #{(before - after) // 1024}K, #{(100 - after * 100 // before)}%)"
  else
    STDERR.puts "[webp] nothing converted."
  end
when "backdrop"
  # mj backdrop <image.png> [name] — import a full-frame image (e.g. a base/strip output) into the
  # backdrop library so it appears in the shadowbox palette as a cut:false entry.
  MJ::Config.load!
  src = ARGV[1]?
  unless src && File.file?(src)
    STDERR.puts "Usage: mj backdrop <image.png> [name]   (imports into #{MJ::Config.backdrops_dir})"
    exit 1
  end
  name = (ARGV[2]? || File.basename(src, File.extname(src))).gsub(/[^A-Za-z0-9._-]/, "-")
  Dir.mkdir_p(MJ::Config.backdrops_dir)
  dst = File.join(MJ::Config.backdrops_dir, name + ".png")
  if File.extname(src).downcase == ".png"
    File.copy(src, dst)
  elsif MJ::Webp.available? # convert non-PNG to PNG (the library reads dims from the PNG header)
    MJ::Webp.encode(src, dst) # magick handles any->png by the .png extension
  else
    File.copy(src, dst)
  end
  STDERR.puts "[backdrop] imported -> #{dst}"
when "version", "--version", "-v"
  puts "mj #{MJ::VERSION}"
else
  STDERR.puts "Usage: mj [init|serve|strip|base|prop|pixelize|decorate|sfx|webp|backdrop|bus|version]"
  exit 1
end
