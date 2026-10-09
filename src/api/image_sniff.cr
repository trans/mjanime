module MJ
  # What kind of image is this, from its first bytes.
  #
  # Needed because callers hand us whatever they have — DataDungeon stores webp, the prop
  # pipeline produces png, a phone photo is jpeg — and both providers want a truthful
  # content type. `upload_image_bytes` used to label every reference `data:image/png`
  # regardless of content; Runware tolerated it because it sniffs the body itself and
  # ignores the label, so this was luck rather than correctness.
  module ImageSniff
    def self.mime(bytes : Bytes) : String
      kind(bytes)[1]
    end

    def self.extension(bytes : Bytes) : String
      kind(bytes)[0]
    end

    # {extension, mime}. Defaults to png, which is what every provider accepts and what
    # this codebase produces by default.
    def self.kind(bytes : Bytes) : {String, String}
      return {"png", "image/png"} if png?(bytes)
      return {"jpg", "image/jpeg"} if jpeg?(bytes)
      return {"webp", "image/webp"} if webp?(bytes)
      return {"gif", "image/gif"} if gif?(bytes)
      {"png", "image/png"}
    end

    def self.png?(b : Bytes) : Bool
      b.size > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47
    end

    def self.jpeg?(b : Bytes) : Bool
      b.size > 3 && b[0] == 0xFF && b[1] == 0xD8
    end

    def self.webp?(b : Bytes) : Bool
      return false unless b.size > 12
      String.new(b[0, 4]) == "RIFF" && String.new(b[8, 4]) == "WEBP"
    end

    def self.gif?(b : Bytes) : Bool
      b.size > 6 && String.new(b[0, 3]) == "GIF"
    end
  end
end
