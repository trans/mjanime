require "file_utils"

module MJ
  module Arcana
    # PNG -> XCF, via a headless GIMP.
    #
    # Why bother, when XCF is many times larger than webp: XCF stores image data in TILES.
    # Two revisions of the same picture that differ in a small region share almost all of
    # their tiles, so a content-addressed store keeps one copy of the shared data and only
    # the changed tiles per revision. Measured on a 768x1024 panel with a 64x64 edit
    # (0.52% of pixels), chunked with a FastCDC-style rolling hash:
    #
    #   xcf    97.7% of chunks shared,  32,906 new bytes per revision
    #   png     0.0%,                  680,927 new bytes — a full rewrite
    #   webp    0.0%,                   88,694 new bytes — a full rewrite
    #
    # Two caveats that decide whether it is worth it:
    #
    # 1. It needs CONTENT-DEFINED chunking. With fixed-size blocks XCF shared only 4.6%,
    #    because GIMP RLE-compresses each tile, so one changed tile shifts every byte after
    #    it and fixed offsets stop lining up. FastCDC is fine; a fixed-block store is not.
    # 2. XCF's first copy is ~13x a webp. Break-even against storing a fresh webp each time
    #    is around 19 revisions. This is a format for art that gets edited repeatedly, and
    #    a bad deal for art written once.
    module Xcf
      class Error < Exception; end

      # Converting costs about 1.4s of local CPU — GIMP start-up dominates, not the image.
      def self.available? : Bool
        !!Process.find_executable("gimp-console")
      end

      def self.convert(png : Bytes) : Bytes
        raise Error.new("gimp-console is not installed — XCF conversion needs GIMP") unless available?

        dir = File.tempname("mj-xcf-")
        Dir.mkdir_p(dir)
        begin
          src = File.join(dir, "in.png")
          dst = File.join(dir, "out.xcf")
          script = File.join(dir, "conv.py")
          File.write(src, png)

          # GIMP 3 requires the batch interpreter to be named, and its Script-Fu PDB
          # signatures changed from GIMP 2, so drive it through python-fu instead.
          File.write(script, <<-PY)
            from gi.repository import Gimp, Gio
            img = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE,
                                 Gio.File.new_for_path(#{src.inspect}))
            Gimp.file_save(Gimp.RunMode.NONINTERACTIVE, img,
                           Gio.File.new_for_path(#{dst.inspect}), None)
            PY

          err = IO::Memory.new
          status = Process.run("gimp-console",
            ["-idf", "--batch-interpreter", "python-fu-eval",
             "-b", "exec(open(#{script.inspect}).read())", "--quit"],
            output: Process::Redirect::Close, error: err)

          unless status.success? && File.exists?(dst)
            raise Error.new("gimp-console failed to write XCF: #{err.to_s.lines.last(3).join(" ")}")
          end
          File.read(dst).to_slice
        ensure
          FileUtils.rm_rf(dir)
        end
      end
    end
  end
end
