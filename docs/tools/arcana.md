# `mj-arcana` — mj's services on the bus

A separate binary (`src/mj-arcana.cr`) that registers **two** services on the Arcana daemon. Not to
be confused with [`mj bus`](bus.md), which exposes mj's *engines* (prop, pixelize, base, decorate,
sfx) under the single address `mj`.

```
mj-arcana                      # registers both services, blocks on the WebSocket loop
```

Each service registers only if its key is present: `RUNWARE_API_KEY` for `mj:camera`,
`OPENAI_API_KEY` and/or `ELEVENLABS_API_KEY` for `mj:voice`. Bus URL comes from `ARCANA_WS_URL` /
`ARCANA_URL`, default `ws://localhost:19118/bus`.

## Why this is separate from arcana

Arcana supplies the communication infrastructure; owners supply the services. A bus that also ships
every provider integration becomes a monolith with a bus inside it, and each integration then ages
at the speed of whoever last cared about it. Two identity methods in `arcana-ai` (ACE++ and PuLID)
were silently broken against the live Runware API for months for exactly that reason — nobody who
lives in bus code wakes up thinking about Runware's parameter drift.

`mj:voice` is the TTS service moved off the arcana server. The provider code stays in `arcana-ai`
(a library); only the exposure moved.

## ⚠️ `Toolset#start` does not register you

`ts.start` installs a message handler and nothing else. **`Client#connect` is what opens the socket
and sends the join frame that creates the directory listing.** Without it the service starts, logs
cheerfully, and is invisible to every caller. `connect` blocks running the WebSocket loop, so with
two services every client but the last needs its own fiber.

## `mj:camera`

```
{"tool":"cameras"}                                    # the list, with measured cost and latency
{"tool":"shoot","camera":"klein","prompt":"…",
 "reference_base64":"…","width":768,"height":1024}
```

The caller supplies intent and nothing else. The service owns the per-model knowledge every caller
otherwise reimplements and gets wrong.

| camera | model | USD | sec | sizes |
| --- | --- | --- | --- | --- |
| `klein` | `runware:400@2` | 0.0059 | 9.6 | 128–2048, step 16 |
| `sunburst` | `openai:gpt-image@2.5-sunburst` | 0.0139 | 20 | 16–3840, step 16 |
| `flare` | `openai:gpt-image@2.5-flare` | 0.0148 | 17 | 16–3840, step 16 |
| `lite` | `google:nano-banana@2-lite` | 0.0340 | **6.1** | Nano fixed set |
| `kontext` | `bfl:3@1` | 0.0400 | 8.7 | its own fixed set |
| `nano` | `google:4@3` | 0.0692 | 12.5 | Nano fixed set |
| `hero` | `openai:4@1` | 0.1362 | 20 | 1024², 1536×1024, 1024×1536 |

Costs and timings are **measured** via Runware's `includeCost`, not quoted from docs. Note latency
does **not** follow price — `lite` is the fastest thing here and mid-priced.

**Size snapping.** Models reject unsupported sizes outright rather than snapping, so this happens
before the request goes out. Two regimes:

- **Range** (`klein`, `flare`, `sunburst`): scale uniformly to fit the bounds — which preserves the
  caller's aspect exactly — then round each side to the step. Rounding is the only drift, and it is
  small: 1920×1080 → 1920×1088, −0.7%.
- **List** (`nano`, `lite`, `kontext`, `hero`): no geometry to adjust, so select the nearest,
  weighting aspect ten times area. A wrong aspect ruins the composition; a wrong area only
  resamples. Aspect distance is compared in **log space** so portrait and landscape errors are
  symmetric — plain `|w/h − want|` is not.

Snapping only decides what size to **ask for**. The service never resamples or crops, so asking
`nano` for 1024×768 returns a real 1200×896 image; the response reports the size actually produced.

**Reference-blind models are refused, not billed.** `FLUX.1 schnell` discards a reference image
silently and returns a byte-identical picture with or without one.

## What a result carries

A caller keeping a ledger and a cache needs more than pixels back.

```
{ "status":"ok", "camera":"klein", "version":1, "model":"runware:400@2",
  "width":768, "height":1024, "bytes":86902, "format":"webp",
  "usd":0.00416, "usd_estimated":false, "seed":4242,
  "image_base64":"…", "content_type":"image/webp" }
```

- **`usd`** is what the provider billed, from Runware's `includeCost` — not a rate card.
  `usd_estimated` says which: `false` is the real figure, `true` means the provider reported
  nothing and this is the registry's average. The average is never silently substituted for a
  reported price, so the flag is trustworthy.
- **`version`** is the cache-invalidation handle. Bump it whenever anything that changes a
  camera's output changes — model id, default parameters, prompt scaffolding. Callers key on
  `(camera, version, prompt, reference)` and a bump tells them their stored pictures are stale.
- **`width`/`height`** are the size actually produced, after snapping — not what was asked for.
- **`quality`** (from `cameras`) ranks the cameras ascending. It is a judgement over the model
  survey, not a measurement, and it is labelled as one.

## Refusals are an outcome, not an error

A content filter saying no is unbilled, probabilistic — Nano refuses prompts it accepted minutes
earlier — and the caller's right move is a retry or a tamer prompt. So it gets its own status, and
**never a quiet fallback to another camera**: a silent substitution would put a lie in the caller's
ledger.

```
{ "status":"refused", "camera":"flare", "version":1, "usd":0.0,
  "categories":["self-harm"], "retry":true, "reason":"<provider text>" }
```

**Match the safety language, never the error code.** Each provider words it differently and the
code is actively misleading:

| provider | how a refusal reads |
| --- | --- |
| Google | `invalidProviderContent`, "content moderation", "Responsible AI" |
| OpenAI | "rejected by the safety system … `safety_violations=[self-harm]`" — under code `providerBadRequest`, **the same code it returns for a bad parameter** |

Classifying on `providerBadRequest` would file genuine errors as refusals and tell callers to retry
something that will never work. Verified both directions: a safety refusal classifies, and an
`invalidImage` 400 still raises. `categories` is parsed out of OpenAI's prose so an automatic retry
can branch on the violation without parsing English.

The markers were collected from live refusals. Don't add one speculatively — an over-broad marker
converts real failures into infinite retry loops.

**Formats** — `webp` (default), `png`, `jpg`, `xcf`. Measured on one 768×1024 panel:

| format | on the wire | note |
| --- | --- | --- |
| webp | 119 KB | **26× smaller than png**; alpha-capable |
| jpg | 238 KB | no alpha, and rings along the black outlines comic art is made of |
| png | 3.1 MB | lossless |
| xcf | ~919 KB | GIMP's tiled format — see below |

**Returns base64 by default**, not a path: bus services are filesystem-isolated. The `runware`
service reports success writing to a `/tmp` nobody else can see. `output_path` works only where
caller and service genuinely share a filesystem.

## XCF and deduplication

`format: "xcf"` converts locally through headless GIMP 3 (~1.4 s; GIMP 3 needs
`--batch-interpreter python-fu-eval` — its Script-Fu PDB signatures changed from GIMP 2).

XCF stores image data in **tiles**, so two revisions differing in a small region share almost all of
them. Measured on a 768×1024 panel with a 64×64 edit (0.52 % of pixels):

| format | chunks shared | new bytes per revision |
| --- | --- | --- |
| xcf | **97.7 %** | 32,906 |
| png | 0 % | 680,927 |
| webp | 0 % | 88,694 |

Two conditions decide whether it pays:

1. **It needs content-defined chunking** (FastCDC). Under *fixed-size* blocks XCF manages only
   4.6 %, because GIMP RLE-compresses each tile, so one changed tile shifts every byte after it.
2. **Break-even is ~19 revisions** — XCF's first copy is ~9× a webp. This is a format for assets
   that get reworked, and a bad trade for generate-and-serve.

A writer we controlled could emit *uncompressed* tiles, which would restore stable offsets and make
dedup work under any chunking scheme. No library does this: `gimpformats`' `save` raises
`NotImplementedError` on purpose, and the ecosystem has readers but essentially no writers.

## `mj:voice`

```
{"tool":"voices"}                                     # providers and voices available on this host
{"tool":"speak","text":"…","provider":"openai"|"elevenlabs","voice":"…"}
```

Same OpenAI provider as arcana's old `openai:tts`, so migration is close to a rename. Two
differences: **ElevenLabs is offered** (it was fully implemented in `arcana-ai` and simply never
wired to the bus), and it accepts **`previous_text` / `next_text`** for prosody continuity across
consecutive lines — the thing that stops synthesized narration sounding like a list of sentences.

Returns `audio_base64` unless `output_path` is given. Inline still round-trips through a temp file
because `arcana-ai`'s `TTS::Provider` has no `synthesize_bytes` yet; its own TODO notes this.

**`speak` cannot report a cost**, and says so rather than guessing. Neither OpenAI nor ElevenLabs
returns a price in the response — there is no `includeCost` equivalent. It returns `usd: null`, a
`usd_note`, and `characters`, the billable unit; the caller applies its own rate card. Multiplying
by an invented rate would put a guess into someone else's ledger as if it were fact.

## Qualifying a new camera

See **[techniques § Probing a model before you trust it](../techniques.md)**. Three checks, all
free, all catching things that are invisible once a service is running.
