require "../config"

module MJ
  module Arcana
    # Where a caller's `output_path` may write: inside one directory, ~/.local/share/mj/out,
    # and never over an existing file.
    #
    # Checked before the provider is called, because the provider bills for what it makes
    # whether or not it can then be written: two ElevenLabs takes asked to write outside
    # the sandbox's writable paths were billed, then failed "Read-only file system"
    # (2026-10-21). Confined because the sandbox alone lets a caller overwrite anything
    # under ~/.local/share/mj, the spend ledger and the libraries included (the security
    # review, 2026-10-21).
    module OutputPath
      def self.dir : String
        File.join(Config.xdg_data_home, "mj", "out")
      end

      # The path to write, given a caller's `output_path`: a name inside `dir`, or an
      # absolute path under it. Subdirectories are made as needed. Raises, before
      # anything is billed, for a path outside `dir`, through a symlink, or naming a file
      # that already exists.
      def self.check!(path : String) : String
        root = dir
        Dir.mkdir_p(root)
        unless File.info(root, follow_symlinks: false).directory?
          refuse(path, "can't be written: #{root} is not a directory")
        end
        full = File.expand_path(path, root)
        refuse(path, "is outside #{root}") unless full.starts_with?(root + "/")
        here = root
        File.dirname(full)[root.size..].split('/', remove_empty: true).each do |part|
          here = File.join(here, part)
          if info = File.info?(here, follow_symlinks: false)
            refuse(path, "goes through #{here}, which is not a directory") unless info.directory?
          else
            Dir.mkdir(here)
          end
        end
        refuse(path, "already exists, and outputs are never overwritten") if File.info?(full, follow_symlinks: false)
        full
      end

      # Write `bytes` to a path from `check!`. Through a temporary file and a hard link,
      # so the name appears only once whole, and a file or symlink that has appeared
      # there since is never overwritten or followed.
      def self.write(full : String, bytes : Bytes) : Nil
        tmp = File.tempfile(".mj-out", dir: File.dirname(full)) { |f| f.write(bytes) }
        begin
          File.link(tmp.path, full)
        rescue File::AlreadyExistsError
          raise "output_path #{full}: appeared while this was being made; not overwritten"
        ensure
          tmp.delete
        end
      end

      private def self.refuse(path : String, why : String) : NoReturn
        raise "output_path #{path.inspect} #{why}. Name a file inside #{dir}, or omit " \
              "output_path to get base64. Nothing was billed."
      end
    end
  end
end
