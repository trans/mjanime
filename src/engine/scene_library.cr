require "json"

module MJ
  # Scene library: shadowbox compositions saved as <name>.json under Config.scenes_dir. A scene is a
  # self-describing JSON document (the editor's export shape), so — unlike the prop library — it needs
  # no folder-per-item and no separate manifest; a listing just scans the directory. Same relocatable
  # pattern as the prop/backdrop libraries, so it maps onto a future TransFS/DataDungeon backend.
  module SceneLibrary
    def self.root : String
      Config.scenes_dir
    end

    # A filesystem-safe scene name: basename only (no dir), drop a trailing .json, and keep just
    # portable characters — so a crafted name can never escape the library root.
    def self.safe_name(name : String) : String
      base = File.basename(name).sub(/\.json\z/i, "")
      cleaned = base.gsub(/[^A-Za-z0-9._-]/, "-")
      cleaned.empty? ? "untitled" : cleaned
    end

    def self.path_for(name : String) : String
      File.join(root, safe_name(name) + ".json")
    end

    # Lightweight listing: {name, layers, updated} per scene, sorted by name.
    def self.list : Array(NamedTuple(name: String, layers: Int32, updated: String))
      dir = root
      items = [] of NamedTuple(name: String, layers: Int32, updated: String)
      return items unless Dir.exists?(dir)
      Dir.each_child(dir) do |f|
        next unless f.ends_with?(".json")
        path = File.join(dir, f)
        next unless File.file?(path)
        layers = 0
        begin
          layers = JSON.parse(File.read(path))["layers"]?.try(&.as_a?.try(&.size)) || 0
        rescue
          # unreadable/corrupt scene still lists (with 0 layers) rather than vanishing
        end
        items << {name: File.basename(f, ".json"),
                  layers: layers,
                  updated: File.info(path).modification_time.to_rfc3339}
      end
      items.sort_by!(&.[:name])
      items
    end

    def self.read(name : String) : String?
      path = path_for(name)
      File.exists?(path) ? File.read(path) : nil
    end

    # Validate that `body` is a scene (parses and carries a `layers` array), then write it. Returns
    # the safe name it was stored under. Raises on invalid JSON or a missing layers array.
    def self.save(name : String, body : String) : String
      json = JSON.parse(body) # raises on malformed JSON
      raise "scene JSON must have a \"layers\" array" unless json["layers"]?.try(&.as_a?)
      Dir.mkdir_p(root)
      sname = safe_name(name)
      File.write(path_for(sname), body)
      sname
    end

    def self.delete(name : String) : Bool
      path = path_for(name)
      return false unless File.exists?(path)
      File.delete(path)
      true
    end
  end
end
