require "json"
require "yaml"
require "uuid"
require "base64"
require "http/client"
require "stumpy_png"

# A deliberately narrow slice of mj — the bus daemon has no business pulling in kemal,
# sqlite or the web routes. If this list starts growing, that is a sign something in the
# services reached somewhere it should not.
require "./config"
require "./api/spend"
require "./api/generator"
require "./api/dimensions"
require "./api/controlnet"
require "./api/runware_client"
require "./engine/canvas_util"
require "./arcana/camera_service"
require "./arcana/voice_service"
require "arcana-core"

# mj-arcana — mj's services on the Arcana bus.
#
# Arcana supplies the communication infrastructure; owners supply the services. Keeping
# every provider integration inside the bus turns it into a monolith with a bus inside it,
# and each integration then ages at the speed of whoever last cared about it. (Two dead
# identity methods sat in arcana-ai for months for exactly that reason — no error, no
# owner, no one looking.)
#
# Two services, registered separately so they can be discovered and run independently:
#
#   mj:camera — image generation behind a camera abstraction. The caller supplies intent;
#               this service owns the per-model geometry rules, parameter spellings and
#               known failure modes that callers otherwise reimplement and get wrong.
#   mj:voice  — text to speech, OpenAI and ElevenLabs. Ported out of the arcana server;
#               the provider code stays in arcana-ai, only the exposure moves.
#
# Environment:
#   ARCANA_WS_URL / ARCANA_URL   bus address (default ws://localhost:19118/bus)
#   RUNWARE_API_KEY              required for mj:camera
#   OPENAI_API_KEY               enables openai speech
#   ELEVENLABS_API_KEY           enables elevenlabs speech

DIM   = "\e[2m"
BOLD  = "\e[1m"
RESET = "\e[0m"
GREEN = "\e[32m"
AMBER = "\e[33m"
GRAY  = "\e[90m"

def log(msg : String)
  STDERR.puts "#{GRAY}#{Time.local.to_s("%H:%M:%S")}#{RESET} #{msg}"
end

bus_url = ENV["ARCANA_WS_URL"]? ||
          ENV["ARCANA_URL"]?.try(&.sub(/^http/, "ws")) ||
          "ws://localhost:19118/bus"

clients = [] of Arcana::Client

STDERR.puts "#{DIM}┌──────────────────────────────────────────────────#{RESET}"
STDERR.puts "#{DIM}│#{RESET} mj-arcana  #{DIM}│#{RESET} #{bus_url}"
STDERR.puts "#{DIM}└──────────────────────────────────────────────────#{RESET}"

# --- mj:camera ------------------------------------------------------------------------
if key = ENV["RUNWARE_API_KEY"]?
  rw = MJ::RunwareClient.new(key)
  cam_client = Arcana::Client.new(
    url: bus_url,
    address: "mj:camera",
    name: "mj Camera",
    description: "Image generation behind a camera abstraction — pick a camera, hand it a " \
                 "prompt and a reference image, get a picture. Carries a character into new " \
                 "poses. Knows each model's supported sizes, parameter shape and failure modes.",
    kind: Arcana::Directory::Kind::Service,
    guide: <<-GUIDE,
      {"tool":"cameras"} lists every camera with its MEASURED usd and seconds, its
      supported sizes, a `quality` rank (higher is better; a judgement, not a measurement)
      and a `version` that bumps whenever anything changing its output changes — key your
      caches on it.

      {"tool":"shoot","camera":"klein","prompt":"...","reference_base64":"...",
       "width":768,"height":1024,"format":"webp","seed":123,"output_path":"..."}

      Reply always carries `status`. "ok" gives camera, version, model, width, height
      (the size SNAPPED to — the service never resamples, so this may differ from what you
      asked), bytes, format, usd and usd_estimated, seed when you supplied one, and either
      image_base64 + content_type or output_path.

      "refused" means the provider's content filter declined. It is UNBILLED (usd 0),
      carries a reason, and retry:true — refusals are probabilistic, so the same prompt may
      pass on a retry. Real errors are raised as errors; a camera is NEVER silently
      substituted for another.

      Prefer reference_base64 over reference_path: bus services do not share a filesystem.
      Prefer format webp — 26x smaller on the wire than png. If you pass a reference, say
      "in the same style" rather than describing the style; an over-specified style fights
      the reference image.
      GUIDE
    tags: ["image", "generation", "camera", "runware"],
  )
  cam_ts = Arcana::Toolset.new(client: cam_client, name: "mj:camera",
    description: "Image generation behind a camera abstraction.")
  MJ::Arcana::CameraService.register(cam_ts, rw)
  cam_ts.start
  clients << cam_client
  log "#{GREEN}●#{RESET} #{BOLD}mj:camera#{RESET} #{DIM}— #{MJ::Arcana::Cameras::ALL.size} cameras, " \
      "#{sprintf("$%.4f", MJ::Arcana::Cameras.list.first.cost)}–" \
      "#{sprintf("$%.4f", MJ::Arcana::Cameras.list.last.cost)} per image#{RESET}"
else
  log "#{AMBER}○#{RESET} mj:camera #{DIM}— skipped, RUNWARE_API_KEY not set#{RESET}"
end

# --- mj:voice -------------------------------------------------------------------------
voices = MJ::Arcana::VoiceService.available
if voices.empty?
  log "#{AMBER}○#{RESET} mj:voice #{DIM}— skipped, no OPENAI_API_KEY or ELEVENLABS_API_KEY#{RESET}"
else
  voice_client = Arcana::Client.new(
    url: bus_url,
    address: "mj:voice",
    name: "mj Voice",
    description: "Text to speech — OpenAI and ElevenLabs. Ported out of the arcana server " \
                 "so the bus is not also a provider.",
    kind: Arcana::Directory::Kind::Service,
    guide: <<-GUIDE,
      {"tool":"voices"} lists the providers actually usable on this host (a provider only
      appears if its key is set) and their voices.

      {"tool":"speak","text":"...","provider":"openai"|"elevenlabs","voice":"...",
       "format":"opus","instructions":"...","speed":1.0,
       "previous_text":"...","next_text":"...","output_path":"..."}

      `instructions` and `speed` are OpenAI only. `previous_text`/`next_text` are ElevenLabs
      only and give prosody continuity across consecutive lines — worth using when a passage
      is synthesized as several clips, or each reads as if it were the only sentence.

      Reply carries `status`. "ok" gives provider, model, voice, format, characters,
      content_type, content_length, and either audio_base64 or output_path. "refused" means
      the provider declined the text: unbilled, with a reason and retry:true. A provider is
      NEVER silently substituted for another.

      NOTE ON COST: `usd` is null. Neither provider reports a price in the response, unlike
      Runware's includeCost, so rather than put a guess in your ledger the reply gives
      `characters` — bill it with your own rate card.
      GUIDE
    tags: ["tts", "voice", "speech", "audio"],
  )
  voice_ts = Arcana::Toolset.new(client: voice_client, name: "mj:voice",
    description: "Text to speech.")
  MJ::Arcana::VoiceService.register(voice_ts)
  voice_ts.start
  clients << voice_client
  log "#{GREEN}●#{RESET} #{BOLD}mj:voice#{RESET} #{DIM}— #{voices.join(", ")}#{RESET}"
end

if clients.empty?
  STDERR.puts "\nNo services could start — set RUNWARE_API_KEY and/or OPENAI_API_KEY."
  exit 1
end

STDERR.puts ""

Signal::INT.trap do
  STDERR.puts ""
  log "#{AMBER}●#{RESET} shutting down"
  clients.each { |c| c.close rescue nil }
  exit 0
end

# Toolset#start only installs the message handler. Client#connect is what opens the socket
# and sends the join frame that creates the directory listing — without it the service runs
# happily and is invisible to everyone. It blocks running the WebSocket loop, so with two
# services every client but the last needs its own fiber.
clients[0...-1].each do |c|
  spawn do
    begin
      c.connect
    rescue ex
      STDERR.puts "#{AMBER}●#{RESET} #{c.address} disconnected: #{ex.message}"
    end
  end
end
Fiber.yield
log "listening"
clients.last.connect
