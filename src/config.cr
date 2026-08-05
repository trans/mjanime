module MJ
  module Config
    CONFIG_DIR  = ".config/mj"
    CONFIG_FILE = "config.yml"

    class_property data_dir : String = "./data"
    # Root of the prop library — a self-contained, relocatable tree (one folder per prop).
    # Kept OUTSIDE the repo by default so it survives repo moves and maps cleanly onto a
    # future TransFS/DataDungeon backend (switching backends = repoint this root + adapter).
    # Resolved in load! to $MJ_PROPS_DIR, else $XDG_DATA_HOME/mj/props, else ~/.local/share/mj/props.
    class_property props_dir : String = ""
    # Root of the backdrop library — full-frame background images for shadowbox scenes (the cut:false
    # palette entries; props supply cut:true). Same relocatable pattern as props_dir. Resolved in
    # load! to $MJ_BACKDROPS_DIR, else $XDG_DATA_HOME/mj/backdrops, else ~/.local/share/mj/backdrops.
    class_property backdrops_dir : String = ""
    class_property runware_api_key : String = ""
    class_property openai_api_key : String = ""
    class_property port : Int32 = 21683 # `cyclops-port mj` (crc32-stable, avoids collisions)

    # XDG data base ($XDG_DATA_HOME, else ~/.local/share).
    def self.xdg_data_home : String
      xdg = ENV["XDG_DATA_HOME"]?
      return File.expand_path("~/.local/share", home: true) if xdg.nil? || xdg.empty?
      xdg
    end

    # Default library roots, honouring the XDG base-dir spec.
    def self.default_props_dir : String
      File.join(xdg_data_home, "mj", "props")
    end

    def self.default_backdrops_dir : String
      File.join(xdg_data_home, "mj", "backdrops")
    end

    class ProjectConfig
      include YAML::Serializable

      property data_dir : String = "./data"
      property props_dir : String? = nil     # nil = use the computed XDG default
      property backdrops_dir : String? = nil # nil = use the computed XDG default
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
      cfg_props_dir : String? = nil
      cfg_backdrops_dir : String? = nil
      if File.exists?(config_path)
        project_config = ProjectConfig.from_yaml(File.read(config_path))
        @@data_dir = project_config.data_dir
        @@port = project_config.port
        cfg_props_dir = project_config.props_dir
        cfg_backdrops_dir = project_config.backdrops_dir
      end

      # Env vars override config file
      @@runware_api_key = ENV["RUNWARE_API_KEY"]? || ""
      @@openai_api_key = ENV["OPENAI_API_KEY"]? || ""
      @@data_dir = ENV["MJ_DATA_DIR"]? || @@data_dir
      # Prop root precedence: $MJ_PROPS_DIR > config file > XDG default.
      @@props_dir = ENV["MJ_PROPS_DIR"]? || cfg_props_dir || default_props_dir
      @@props_dir = File.expand_path(@@props_dir, home: true)
      # Backdrop root: $MJ_BACKDROPS_DIR > config file > XDG default.
      @@backdrops_dir = ENV["MJ_BACKDROPS_DIR"]? || cfg_backdrops_dir || default_backdrops_dir
      @@backdrops_dir = File.expand_path(@@backdrops_dir, home: true)
      @@port = ENV["PORT"]?.try(&.to_i) || @@port

      if @@runware_api_key.empty?
        STDERR.puts "WARNING: RUNWARE_API_KEY not set. Image generation will fail."
      end
    end
  end
end
