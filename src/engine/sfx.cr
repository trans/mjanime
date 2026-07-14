module MJ
  # Fit a procedural Web Audio SFX recipe from a reference sound (analysis -> parameters).
  # The DSP analyzer is Python (numpy/scipy/ffmpeg); its source is embedded in the binary at
  # compile time and written to a temp file on first use, so mj stays a single artifact.
  #
  # Output is a `.sfx.json` recipe: {source, filters[], wobble, env} — playable in-browser by
  # a tiny generic Web Audio player (no audio assets). Optionally renders an approximation wav.
  #
  # Runtime deps: python3, numpy, scipy, ffmpeg.
  module Sfx
    PY_SRC = {{ read_file("#{__DIR__}/sfx_fit.py") }}

    @@script_path : String? = nil

    private def self.script : String
      @@script_path ||= begin
        path = File.tempname("mj_sfx_fit", ".py")
        File.write(path, PY_SRC)
        path
      end
    end

    # Analyze a reference sound and return the fitted recipe. If preview_path is given,
    # also renders an approximation wav there.
    def self.fit(input_path : String, preview_path : String? = nil) : JSON::Any
      raise "audio file not found: #{input_path}" unless File.exists?(input_path)
      args = ["python3", script, input_path]
      args += ["--preview", preview_path] if preview_path
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = begin
        Process.run(args[0], args[1..], output: stdout, error: stderr)
      rescue File::NotFoundError
        raise "sfx needs python3 (with numpy, scipy) and ffmpeg on PATH."
      end
      raise "sfx analyzer failed: #{stderr.to_s.strip}" unless status.success?
      JSON.parse(stdout.to_s)
    end
  end
end
