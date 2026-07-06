require "./lib"

case ARGV[0]?
when "init"
  Minanime::Config.init!
when "serve", nil
  unless Minanime::Config.initialized?
    STDERR.puts "Not a minianime project. Run `minanime init` first."
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
when "version", "--version", "-v"
  puts "minanime #{Minanime::VERSION}"
else
  STDERR.puts "Usage: minanime [init|serve|strip|version]"
  exit 1
end
