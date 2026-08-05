require "json"
require "digest/sha256"

module MJ
  # The prop library: a self-contained, relocatable tree under `Config.props_dir`
  # (default ~/.local/share/mj/props). One folder per prop — `<root>/<name>/` holding
  # `prop.yml` (recipe), `template.png` (input), `render.png` (raw), `prop.png`
  # (deliverable) — plus a top-level `index.json` manifest. The manifest carries the
  # tag/provenance metadata a future TransFS/DataDungeon backend will index on, so
  # migrating backends is "repoint the root + write an adapter", not a rewrite.
  module PropLibrary
    # One manifest row per prop. Provenance is regenerable from prop.yml + template.png.
    struct Entry
      include JSON::Serializable
      property name : String
      property tags : Array(String)
      property model : String
      property width : Int32
      property height : Int32
      property source_sha : String # sha256(prop.yml) — changes when the recipe changes
      property created : String     # RFC3339, preserved across rebuilds
      property updated : String     # RFC3339, bumped every build

      def initialize(@name, @tags, @model, @width, @height, @source_sha, @created, @updated)
      end
    end

    class Manifest
      include JSON::Serializable
      property props : Array(Entry) = [] of Entry

      def initialize
        @props = [] of Entry
      end
    end

    def self.root : String
      Config.props_dir
    end

    def self.manifest_path : String
      File.join(root, "index.json")
    end

    # Resolve an argument to a prop directory. A bare name (no path separator) lives in
    # the library root; anything containing a separator or an existing path is treated as
    # an explicit one-off directory. Does not create anything.
    def self.resolve(name_or_path : String) : String
      if name_or_path.includes?('/') || File.directory?(name_or_path)
        name_or_path
      else
        File.join(root, name_or_path)
      end
    end

    # The prop's library name (folder basename), used as the manifest key.
    def self.name_of(dir : String) : String
      File.basename(dir.rstrip('/'))
    end

    def self.load_manifest : Manifest
      path = manifest_path
      return Manifest.new unless File.exists?(path)
      Manifest.from_json(File.read(path))
    rescue
      Manifest.new # a corrupt manifest shouldn't block a build; it gets rewritten
    end

    # Upsert this prop's row and rewrite index.json. `created` is preserved if the prop
    # was already present. Keeps rows sorted by name for stable diffs.
    def self.record(dir : String, spec : PropSpec) : Nil
      name = name_of(dir)
      now = Time.utc.to_rfc3339
      yml = File.join(dir, "prop.yml")
      sha = File.exists?(yml) ? Digest::SHA256.hexdigest(File.read(yml)) : ""
      manifest = load_manifest
      created = manifest.props.find { |e| e.name == name }.try(&.created) || now
      manifest.props.reject! { |e| e.name == name }
      manifest.props << Entry.new(name, spec.tags, spec.model, spec.width, spec.height, sha, created, now)
      manifest.props.sort_by!(&.name)
      Dir.mkdir_p(root)
      File.write(manifest_path, manifest.to_pretty_json)
    end
  end
end
