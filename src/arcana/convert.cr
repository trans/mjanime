require "file_utils"
require "../api/image_sniff"

module MJ
  module Arcana
    # Re-encode an image to the format the caller asked for.
    #
    # Needed because the providers do not agree on what they return, and the whole promise
    # of pools is that moving load between them changes nothing but the queue:
    #
    #   Runware        honours outputFormat — asks for webp, gets lossy VP8 webp
    #   OpenAI direct  honours output_format, and output_compression for the lossy/lossless
    #                  choice (left alone it returns LOSSLESS webp, 8x the bytes)
    #   Google direct  ignores the question entirely and returns JPEG, always
    #
    # Without this, asking the google pool for webp got JPEG bytes labelled `webp` — a
    # caller storing by extension would write a .webp file containing a JPEG. Converting
    # keeps the pools genuinely interchangeable; labelling alone would not.
    module Convert
      class Error < Exception; end

      # Quality for lossy targets. 80 lands near the other pools (measured: Runware webp
      # 0.11 bytes/pixel, OpenAI direct at compression 80 gives 0.04) so panel sizes stay
      # comparable whichever pool served the request.
      QUALITY = 80

      def self.available? : Bool
        !!Process.find_executable("magick")
      end

      # Returns the bytes unchanged when they are already in the target format — the common
      # case, so the usual path costs one sniff and no subprocess.
      def self.ensure(bytes : Bytes, target : String) : Bytes
        want = normalise(target)
        return bytes if ImageSniff.extension(bytes) == want ||
                        (want == "jpg" && ImageSniff.extension(bytes) == "jpg")
        convert(bytes, want)
      end

      def self.convert(bytes : Bytes, target : String) : Bytes
        raise Error.new("converting to #{target} needs ImageMagick, which is not installed") unless available?
        from = ImageSniff.extension(bytes)
        dir = File.tempname("mj-conv-")
        Dir.mkdir_p(dir)
        begin
          src = File.join(dir, "in.#{from}")
          dst = File.join(dir, "out.#{target}")
          File.write(src, bytes)
          args = ["#{src}"]
          # Lossless targets take no quality argument; a quality on png would be read as a
          # compression/filter pair and silently change the encoding.
          args.concat(["-quality", QUALITY.to_s]) if target == "webp" || target == "jpg"
          args << dst
          err = IO::Memory.new
          status = Process.run("magick", args,
            output: Process::Redirect::Close, error: err)
          unless status.success? && File.exists?(dst)
            raise Error.new("magick #{from}->#{target} failed: #{err.to_s.lines.last(2).join(" ")}")
          end
          File.read(dst).to_slice
        ensure
          FileUtils.rm_rf(dir)
        end
      end

      private def self.normalise(fmt : String) : String
        f = fmt.downcase
        f == "jpeg" ? "jpg" : f
      end
    end
  end
end
