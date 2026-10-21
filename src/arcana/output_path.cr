module MJ
  module Arcana
    # A caller's `output_path` is checked before the provider is called, because the
    # provider bills for what it makes whether or not it can then be written. These
    # services run sandboxed (mj-arcana.service: ProtectHome=read-only), so most of the
    # home directory is read-only to them: two ElevenLabs takes asked to write to a
    # scratch folder were billed, then failed "Read-only file system" (2026-10-21).
    module OutputPath
      def self.check!(path : String) : Nil
        dir = File.dirname(File.expand_path(path))
        return if Dir.exists?(dir) && File.writable?(dir)
        why = Dir.exists?(dir) ? "is read-only to this service" : "does not exist"
        raise "output_path #{path}: #{dir} #{why}. This service writes only under " \
              "~/.local/share/mj; omit output_path to get base64. Nothing was billed."
      end
    end
  end
end
