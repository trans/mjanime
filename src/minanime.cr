require "kemal"
require "json"
require "yaml"
require "uuid"
require "base64"
require "http/client"
require "db"
require "sqlite3"

require "./config"
require "./models/motion_script"
require "./models/frame"
require "./models/render_job"
require "./api/generator"
require "./api/runware_client"
require "./api/openai_client"
require "./store/database"
require "./store/frame_store"
require "./store/cut_store"
require "./engine/frame_chain"
require "./engine/renderer"
require "./web/routes"

module Minanime
  VERSION = "0.1.0"

  module App
    @@renderer : Renderer? = nil

    def self.renderer : Renderer
      @@renderer ||= begin
        generator = RunwareClient.new(Config.runware_api_key)
        store = FrameStore.new
        Renderer.new(generator, store)
      end
    end
  end
end

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
  Kemal.config.serve_static = false
  Kemal.run
when "version", "--version", "-v"
  puts "minanime #{Minanime::VERSION}"
else
  STDERR.puts "Usage: minanime [init|serve|version]"
  exit 1
end
