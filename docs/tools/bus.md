# `mj bus` — mj's image tools on the Arcana bus

Join the running Arcana daemon and serve mj's engines as a single bus service, so other agents
(e.g. siliconcircus) can call mj directly.

```
mj bus                         # standalone: connect and block on the receive loop
```

Also started automatically alongside `mj serve` (opt out with `MJ_BUS=0`); if `RUNWARE_API_KEY` is
unset it logs and disables the bus rather than failing the web server.

## Address & dispatch

- Registers as a **single-token address `mj`** (kind = service), a Client-backed `Arcana::Toolset`.
- **Dispatch on the payload `tool` field.** `{"tool":"help"}` returns the tools manifest for free.
- ⚠️ **Do NOT use `mj:image`** — the `owner:capability` form is a **pre-0.24 ghost** shape. Live
  daemon services are single-token (`openai`, `arcana`, `runware`); the `openai:tts`-style entries
  are dead snapshot zombies (no worker on the mailbox → requests time out). To call another service:
  `to:"openai" {tool:"tts", …}`.
- **Bus URL:** `ARCANA_WS_URL` / `ARCANA_URL` (http→ws), default `ws://localhost:19118/bus` (one bus
  per host — the same daemon the arcana MCP bridges to).

## Tools exposed

`pixelize`, `prop`, `base`, `decorate`, `sfx` (`sfx` marked experimental). Each takes a source image
via **`input_path`** (file path) or **`image_base64`**, plus its spec fields and an optional
**`output_path`**; returns `{output_path}` when written, else `{image_base64, content_type}`. Each is
registered with a JSON `input_schema`. The Toolset provides the help manifest, poison-pill guard,
correlation-id preservation, `reply_to` routing, and unknown-tool errors automatically.

```sh
set -a; . ./.env; set +a
./bin/mj bus
# elsewhere, deliver:  to:"mj"  {"tool":"pixelize", "input_path":"/…/image.png", "output_path":"/…/pixel.png", "style":"16bit"}
```

## Soundbox / TTS

The web app's **Sound Box** (`/soundbox`) is a live Web Audio effect chain (pitch/formant, overdrive,
bandpass, ring-mod, tremolo) with WAV export and presets (Robo-Parrot, Full Robot, Grizzled Pirate,
Tiny Bird, Dry) — built for the "robot pirate parrot squawk" voice. Its "Generate voice" button goes
`browser → /soundbox/tts → openai Toolset over the bus → WAV → the effect chain`.

`MJ::BusService.tts(text, voice, …)` is the outbound helper: it sends `{tool:"tts", …}` to the
**live `openai` Toolset** (not the dead `openai:tts` ghost) over the same client connection. The
whole "TTS returned zero bytes" saga was those pre-0.24 ghost addresses — target single-token
Toolsets and dispatch on `tool`.

---
Related: [sfx](sfx.md) · [diorama](diorama.md) · arcana-core (bus)
