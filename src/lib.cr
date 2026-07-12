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
require "./models/pose"
require "./models/strip_script"
require "./models/bed_spec"
require "./models/prop_spec"
require "./models/pixel_spec"
require "./api/generator"
require "./api/dimensions"
require "./api/controlnet"
require "./api/runware_client"
require "./api/openai_client"
require "./engine/pose_renderer"
require "./engine/canvas_util"
require "./store/database"
require "./store/frame_store"
require "./store/cut_store"
require "./engine/frame_chain"
require "./engine/renderer"
require "./engine/strip_builder"
require "./engine/bed"
require "./engine/prop"
require "./engine/pixelize"
require "./web/routes"

module MJ
  VERSION = "0.2.0"

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
