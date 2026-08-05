module MJ
  # Backdrop library: full-frame background images for shadowbox scenes — the cut:false palette
  # entries (the prop library supplies the cut:true cut-outs). A flat directory of image files under
  # Config.backdrops_dir; a backdrop is a single image, so unlike props it needs no folder. PNG for
  # now (dims read straight from the header); .webp support is a later option (P5).
  module BackdropLibrary
    IMAGE_EXTS = %w[.png .webp]

    record Entry, name : String, file : String, w : Int32, h : Int32 do
      def src : String
        "/lib/backdrops/#{file}"
      end
    end

    def self.root : String
      Config.backdrops_dir
    end

    # Every sizeable image in the backdrop dir, sorted by name. Images we can't size yet (e.g. .webp
    # until P5) are skipped rather than listed without dimensions.
    def self.list : Array(Entry)
      dir = root
      return [] of Entry unless Dir.exists?(dir)
      out = [] of Entry
      Dir.each_child(dir) do |f|
        next unless IMAGE_EXTS.includes?(File.extname(f).downcase)
        path = File.join(dir, f)
        next unless File.file?(path)
        if dims = png_dims(path)
          out << Entry.new(File.basename(f, File.extname(f)), f, dims[0], dims[1])
        end
      end
      out.sort_by!(&.name)
      out
    end

    # Width/height from a PNG's IHDR without decoding the pixels. nil for non-PNG or a short file.
    def self.png_dims(path : String) : {Int32, Int32}?
      File.open(path) do |f|
        header = Bytes.new(24)
        return nil unless f.read_fully(header) == 24
        return nil unless header[0] == 0x89_u8 && header[1] == 0x50_u8 &&
                          header[2] == 0x4E_u8 && header[3] == 0x47_u8 # "\x89PNG"
        w = IO::ByteFormat::BigEndian.decode(UInt32, header[16, 4])
        h = IO::ByteFormat::BigEndian.decode(UInt32, header[20, 4])
        {w.to_i, h.to_i}
      end
    rescue
      nil
    end
  end
end
