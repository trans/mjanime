module MJ
  module Config
    CONFIG_DIR  = ".config/mj"
    CONFIG_FILE = "config.yml"

    class_property data_dir : String = "./data"
    class_property runware_api_key : String = ""
    class_property openai_api_key : String = ""
    class_property port : Int32 = 21683 # `cyclops-port mj` (crc32-stable, avoids collisions)

    class ProjectConfig
      include YAML::Serializable

      property data_dir : String = "./data"
      property port : Int32 = 21683 # `cyclops-port mj`

      def initialize(@data_dir = "./data", @port = 21683)
      end
    end

    def self.config_path : String
      File.join(CONFIG_DIR, CONFIG_FILE)
    end

    def self.initialized? : Bool
      File.exists?(config_path)
    end

    def self.init!
      Dir.mkdir_p(CONFIG_DIR)
      unless File.exists?(config_path)
        config = ProjectConfig.new
        File.write(config_path, config.to_yaml)
        puts "Initialized mj project in #{Dir.current}"
        puts "  Created #{config_path}"
      else
        puts "Already initialized (#{config_path} exists)"
      end
    end

    def self.load!
      if File.exists?(config_path)
        project_config = ProjectConfig.from_yaml(File.read(config_path))
        @@data_dir = project_config.data_dir
        @@port = project_config.port
      end

      # Env vars override config file
      @@runware_api_key = ENV["RUNWARE_API_KEY"]? || ""
      @@openai_api_key = ENV["OPENAI_API_KEY"]? || ""
      @@data_dir = ENV["MJ_DATA_DIR"]? || @@data_dir
      @@port = ENV["PORT"]?.try(&.to_i) || @@port

      if @@runware_api_key.empty?
        STDERR.puts "WARNING: RUNWARE_API_KEY not set. Image generation will fail."
      end
    end
  end
end
