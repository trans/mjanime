require "digest/sha256"
require "file_utils"
require "json"

module MJ
  # Segment Anything for the /calibrate page (docs/tools/calibrate.md). A Python helper (sam_helper.py) keeps SAM 2.1
  # loaded on the GPU, because its first answer takes seconds and the rest a fraction of one. It starts at the first
  # request and stops after IDLE, to give the graphics memory back; a helper that dies is started again at the next
  # request. The page sends its picture once, and then only clicks.
  module Sam
    HELPER     = {{ read_file("#{__DIR__}/sam_helper.py") }}
    IDLE       = 15.minutes
    STARTUP    = 10.minutes # the first run on a machine downloads the model
    ANSWER     = 1.minute
    MAX_IMAGE  = 64 * 1024 * 1024
    MAX_POINTS = 32
    IMAGE_ID   = /\A[0-9a-f]{64}\z/

    class BadRequest < Exception; end

    class NoImage < Exception; end

    class Failure < Exception; end

    # What the page asks, in the picture's own pixels: points with a label each (1 "this", 0 "not this"), a box, and
    # what's on screen.
    struct Prompt
      include JSON::Serializable

      getter image : String
      getter points : Array(Array(Float64)) = [] of Array(Float64)
      getter labels : Array(Int32) = [] of Int32
      getter box : Array(Float64)?
      getter view : Array(Float64)?
    end

    class_property script : String = HELPER
    @@lock = Mutex.new
    @@helper : Process?
    @@used = Time.instant
    @@images : String?

    # Keep the picture, under its hash, and return that id.
    def self.store_image(body : IO) : String
      bytes = IO::Memory.new
      IO.copy(body, bytes, MAX_IMAGE + 1)
      raise BadRequest.new("no picture") if bytes.size == 0
      raise BadRequest.new("the picture is over #{MAX_IMAGE // (1024 * 1024)} MB") if bytes.size > MAX_IMAGE
      id = Digest::SHA256.hexdigest(bytes.to_slice)
      File.write(image_path(id), bytes.to_slice, perm: 0o600)
      id
    end

    # The helper's request for the page's, with the picture's id swapped for its path.
    def self.helper_request(body : String) : String
      prompt = begin
        Prompt.from_json(body)
      rescue ex : JSON::Error
        raise BadRequest.new("not a prompt: #{ex.message}")
      end
      raise BadRequest.new("not a picture id") unless prompt.image.matches?(IMAGE_ID)
      raise BadRequest.new("a label for each point") unless prompt.points.size == prompt.labels.size
      raise BadRequest.new("at most #{MAX_POINTS} points") if prompt.points.size > MAX_POINTS
      raise BadRequest.new("a point is x, y") unless prompt.points.all? { |p| p.size == 2 && p.all?(&.finite?) }
      raise BadRequest.new("a label is 1 or 0") unless prompt.labels.all? { |l| l == 0 || l == 1 }
      box = prompt.box
      raise BadRequest.new("a box is x0, y0, x1, y1") if box && !(box.size == 4 && box.all?(&.finite?))
      view = prompt.view
      raise BadRequest.new("a view is x0, y0, x1, y1") if view && !(view.size == 4 && view.all?(&.finite?))
      raise BadRequest.new("a click or a box is needed") unless box || prompt.labels.includes?(1)
      path = image_path(prompt.image)
      raise NoImage.new("no such picture") unless File.exists?(path)
      {image: path, points: prompt.points, labels: prompt.labels, box: box, view: view}.to_json
    end

    # The page's prompt answered: the helper's JSON line.
    def self.answer(body : String) : String
      ask(helper_request(body))
    end

    # One line to the helper, one line back. One at a time: the GPU does one.
    def self.ask(line : String) : String
      @@lock.synchronize do
        helper = @@helper || start
        @@used = Time.instant
        begin
          helper.input.puts line
          helper.input.flush
          helper.output.as(IO::FileDescriptor).read_timeout = ANSWER
          helper.output.gets || raise IO::Error.new("the helper closed")
        rescue ex : IO::Error
          stop
          raise Failure.new("SAM stopped: #{ex.message}")
        end
      end
    end

    private def self.start : Process
      script = File.tempname("mj_sam", ".py")
      File.write(script, @@script)
      helper = begin
        Process.new("python3", ["-P", script], input: :pipe, output: :pipe, error: :inherit)
      rescue ex : File::NotFoundError
        File.delete?(script)
        raise Failure.new("SAM needs python3 on PATH")
      end
      begin
        helper.output.as(IO::FileDescriptor).read_timeout = STARTUP
        first = helper.output.gets || raise IO::Error.new("it closed")
        ready = JSON.parse(first)
        raise Failure.new(ready["error"]?.try(&.as_s?) || first) unless ready["ready"]?
      rescue ex : IO::Error | JSON::ParseException
        kill(helper)
        raise Failure.new("SAM couldn't start: #{ex.message}")
      rescue ex : Failure
        kill(helper)
        raise ex
      ensure
        File.delete?(script)
      end
      @@helper = helper
      @@used = Time.instant
      watch(helper)
      helper
    end

    # Stop this helper once it's been idle a while.
    private def self.watch(helper : Process)
      spawn do
        loop do
          sleep 1.minute
          done = @@lock.synchronize do
            next true unless @@helper == helper
            next false if Time.instant - @@used < IDLE
            stop
            true
          end
          break if done
        end
      end
    end

    private def self.stop
      @@helper.try { |helper| kill(helper) }
      @@helper = nil
    end

    # It stops when its stdin closes; a helper that doesn't is ended.
    private def self.kill(helper : Process)
      helper.input.close rescue nil
      spawn do
        sleep 5.seconds
        helper.terminate unless helper.terminated?
      rescue RuntimeError
      end
      helper.wait rescue nil
    end

    # Where the pictures wait: a folder of this server's, gone when it stops.
    private def self.image_path(id : String) : String
      dir = @@images ||= begin
        path = File.join(Dir.tempdir, "mj-sam-#{Process.pid}")
        Dir.mkdir_p(path, mode: 0o700)
        at_exit { stop; FileUtils.rm_rf(path) }
        path
      end
      File.join(dir, id)
    end
  end
end
