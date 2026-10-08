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

## Running it as a service

```
just install-service      # systemd user unit; builds, installs, enables, starts
just logs
```

Unit and rationale in [`deploy/`](../../deploy/README.md). One trap worth repeating here:
**the unit cannot read `.env`** — that file is bash, and systemd silently ignores
`export KEY=value`, leaving the key unset. Since both services are key-gated, the result is
a unit that reports `active (running)` and registers *nothing*. `just systemd-env`
translates it into `~/.config/mj/env` at mode 600.

## Why this is separate from arcana

Arcana supplies the communication infrastructure; owners supply the services. A bus that also ships
every provider integration becomes a monolith with a bus inside it, and each integration then ages
at the speed of whoever last cared about it. Two identity methods in `arcana-ai` (ACE++ and PuLID)
were silently broken against the live Runware API for months for exactly that reason — nobody who
lives in bus code wakes up thinking about Runware's parameter drift.

`mj:voice` is the TTS service moved off the arcana server. The provider code stays in `arcana-ai`
(a library); only the exposure moved.

## Use `Toolset#run`, not `start`

`ts.start` installs a message handler **and nothing else** — `Client#connect` is what opens the
socket and sends the join frame that creates the directory listing. Call only `start` and the service
runs, logs cheerfully, and is invisible to every caller, with no error anywhere.

**arcana-core 0.15.0 added `Toolset#run`**, which is start + connect in one call, in response to this
exact trap. Use it. It still blocks on the WebSocket loop, so every toolset but the last needs its
own fiber:

```crystal
toolsets[0...-1].each { |ts| spawn { ts.run } }
toolsets.last.run
```

0.15.0 also warns on STDERR if a Client-transport Toolset is still unconnected 5 s after `start`
(tunable via `connect_grace`), so the silent version of this mistake is no longer possible.

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

## Model diversity is not capacity diversity

The camera list looks like four backends — Runware's own FLUX, Google, OpenAI, BFL. It is not. Every
camera posts to **one endpoint, `api.runware.ai/v1`, on one account**; the model ids
(`google:4@3`, `openai:4@1`, `bfl:3@1`) are strings in the request body. The models run on different
infrastructure; **admission control does not.** Under a spike all seven queue behind the same door,
so picking a different camera does not route around congestion.

I had told a caller the opposite — that a congestion episode on one need not touch another — which
would have had them building a cross-camera failover that fails into the same queue. `cameras` now
reports this directly, so it cannot be inferred wrongly from the model ids:

```json
"pools": { "runware": ["klein","flare","sunburst","lite","nano","hero","kontext"] }
```

Cameras in the **same** pool share a queue. Only cameras in **different** pools are independent.

**There are two pools now.** The `openai` pool runs the *same models* directly against our own
OpenAI quota, so load moved onto it is admitted at a different door:

```json
"pools": {
  "runware": ["klein","flare","sunburst","lite","nano","hero","kontext"],
  "openai":  ["dflare","dsunburst","dhero"]
}
```

| direct | same model as | cost | measured | vs twin |
| --- | --- | --- | --- | --- |
| `dflare` | `flare` | 0.0148 | 10.6 s (n=4) | faster than 17.0 s |
| `dsunburst` | `sunburst` | 0.0139 | 11.5 s (n=1) | faster than 20.0 s |
| `dhero` | `hero` | 0.1362 | 33.3 s (n=2) | **slower** than 20.0 s |

Same model, same picture — the only reason to choose one over its twin is which queue you want to be
in. The 2.5 pair being faster direct is unsurprising (one less hop, no shared queue); `dhero` being
slower is the one to remember on a premium shot. Small samples, and Runware's numbers move with its
queue, so treat these as order-of-magnitude.

**Two things had to be equalised** so that moving load between pools changes nothing but the queue:

- **webp encoding.** Left alone, OpenAI direct returns *lossless* webp (`VP8L`, ~0.9 bytes/pixel)
  where Runware returns lossy `VP8 ` at ~0.11 — the same request for 8× the bytes, which would
  ambush a failover. The transport now sends `output_compression: 80`, giving lossy `VP8 ` at
  0.04 B/px. Pass `output_compression: 100` in `extra` for lossless.
- **the no-reference path.** Runware has no text-to-image route, so an unreferenced shot is edited
  onto a flat grey canvas; OpenAI has a real `/images/generations`. That is now each transport's own
  business rather than something the service encodes, so an empty reference list means "no
  reference" and each provider does the right thing with it.

`Transport` (`src/arcana/transport.cr`) is the seam; it documents what a new transport owes the
service. A third pool needs only a key — Google's direct API would add one, and `GEMINI_API_KEY` is
not set on this host.

**Probing OpenAI differs from probing Runware.** Runware validates size before prompt, so an empty
prompt makes size questions free. OpenAI validates the **prompt first**, so that trick returns a
prompt error instead. Use a real prompt with a size you expect to be refused — but note a size that
turns out to be *valid* will generate and bill you. What the probe found, in agreement with the
Runware-side rules: `gpt-image-2.5-*` wants both sides divisible by 16 with the longest edge ≤ 3840
and a minimum total *pixel budget* rather than a per-side floor; `gpt-image-1.5` takes only
1024×1024, 1024×1536, 1536×1024.

**What a second transport buys is a published ceiling, not a better average.** Runware runs a shared
best-effort queue and publishes no limit, so there is no headroom to buy when it stalls. Direct
provider APIs state one and raise it with spend:

| | ceiling | predictable? |
| --- | --- | --- |
| Runware | nothing published; shared queue | no — episodic stalls, measured below |
| Google direct | spend per rolling 10 min: T1 $10 / T2 $50 / T3 $200 (≈4.8 nano images/s) | yes, and purchasable |
| OpenAI direct | tier-based images-per-minute, per account | yes, in the console |

Runware's trade is price and a single integration. A number you can plan against and raise is worth
more under spike than a cheaper average you cannot.

## Heavy traffic: latency, not rejection

Runware enforces **no hard rate limit.** It runs a shared queue, so load shows up as latency, with
429 only once queue capacity is exceeded. Their guidance is 2–4 concurrent requests and app-side
concurrency limits.

What we actually measured, `klein` at 512×512 through the bus:

| concurrency | wall | per-request | failures |
| --- | --- | --- | --- |
| 1 | 4.9 s | 4.9 s | 0 |
| 2 | 126.6 s | 122–127 s | **1 (504)** |
| 4 | 17.9 s | 4.6–17.9 s | 0 |
| 4 | 136.8 s | 5.1–137 s | **1 (504)** |

**Read that table carefully: n=2 was worse than n=4.** The stalls and failures are *not* a function
of our concurrency — they are congestion episodes that come and go, so there is no safe concurrency
number to pick and no amount of client-side throttling that avoids them. Plan for a p50 of a few
seconds and a tail roughly 25× worse. Note also that capacity exhaustion reached us as **504**, not
the documented 429.

Requests do run **concurrently** — the Toolset does not serialize them, so one slow shot does not
block the others.

The client had no defences against any of this and now has two:

- **Timeouts.** Crystal's `HTTP::Client` has *none* by default, so a stalled request waits forever.
  Now 15 s connect, 180 s read (`MJ_RUNWARE_READ_TIMEOUT`), 60 s write. The read timeout is a
  backstop against an indefinite hang, not a latency budget — a caller with a deadline should impose
  its own.
- **Retries** on 408/429/500/502/503/504 and transport errors, with exponential backoff plus jitter,
  twice by default (`MJ_RUNWARE_RETRIES`). A 400 is never retried: a refusal or a bad parameter will
  fail again just as fast. Verified against a local always-503 server — 1 attempt + 2 retries over
  7.3 s, then the provider's own error is handed back rather than a wrapper of ours.

⚠️ **Retries can double-bill.** Runware bills per task, so a 504 arriving *after* the work completed
means the retry pays for a second generation. Without the retry you pay once and get nothing. That is
why the ceiling is 2 and not 10; raise `MJ_RUNWARE_RETRIES` only if you accept the trade.

When the retries are exhausted the caller gets a third outcome, `status: "overloaded"` — unbilled,
`retry: true`, and explicitly *not* a refusal, because the prompt is fine and rewording it is the
wrong response.

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
| webp | 119 KB | **26× smaller than png**; lossy, **no alpha** — see below |
| jpg | 238 KB | no alpha, and rings along the black outlines comic art is made of |
| png | 3.1 MB | lossless |
| xcf | ~919 KB | GIMP's tiled format — see below |

**Runware's webp is lossy and has no alpha**, which is not obvious from asking for "webp". Reading
the bytes of a returned 768×1024 panel: a `VP8 ` chunk rather than `VP8L`, no `VP8X` extended chunk,
0.11 bytes/pixel. The format is alpha-capable; what this API emits is not.

That is the right trade for this service, whose job is serve-and-display. It does mean webp is wrong
as a **pipeline intermediate**: the prop machine generates on a solid background and then
distance-keys it, and lossy chroma smears background colour across exactly the boundary the key
decides on — it would corrupt the rim-bleed-by-hue judgement too. Ask for `png` wherever an alpha
channel or a later key is involved. `runware_client.cr` hardcodes PNG on the background-removal
path for this reason.

We never set `outputQuality`, so the encoder runs at Runware's default.

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

Returns `audio_base64` unless `output_path` is given. **Omit `voice` to get the provider's own
default** — arcana-ai 0.3.0 changed `TTS::Request`'s defaults to `""` for this reason: the old
OpenAI-shaped defaults leaked across providers, so ElevenLabs was sent model `gpt-4o-mini-tts` and
voice `alloy` on every call, silently overriding its constructor. That also broke costing here,
since the ElevenLabs credit multiplier is keyed on the model: Flash and Turbo would have been
charged at 1.0 credits/character instead of 0.5, a 2x overstatement on exactly the cheap models.
Never substitute one provider's default for another's.

Audio comes back in memory — arcana-ai 0.3.0's `synthesize(req)` overload returns `result.audio`, so
there is no temp-file round-trip for delivery.

### Costing a spoken line

No TTS provider reports a price in the response — there is no `includeCost` equivalent — so this is
computed, and the trap is assuming one billing unit. **The two providers do not share one.**

| model | billed on | what we report |
| --- | --- | --- |
| `gpt-4o-mini-tts` (OpenAI default) | tokens — $0.60/1M input chars **+ $12/1M audio output tokens** | estimated from **measured duration** at $0.015/min, OpenAI's published composite |
| `tts-1` / `tts-1-hd` | characters, $15 / $30 per 1M | **exact** — computable from the text alone |
| ElevenLabs | characters, as credits (Flash/Turbo families are 0.5 credits/char, the rest 1.0) | `credits` always; dollars only once a plan rate is configured |

`usd_exact` says which rule applied, and `usd_basis` spells it out in words. A `usd` of `null` means
genuinely unknown — never a guess dressed as a figure, because it would land in the caller's ledger
as fact.

**Why duration and not characters for the token-billed model.** For ordinary English prose the two
agree closely, which makes characters look like a safe proxy. It isn't — the model decides how long
to take. Same 133-character line, measured:

| variant | characters | seconds | usd |
| --- | --- | --- | --- |
| normal | 133 | 8.52 | 0.00213 |
| `speed: 0.5` | 133 | 17.18 | 0.00430 |

Identical text, **2.02× the duration and 2.02× the cost**. A character-based estimate reports the
same price for both and is 100 % under on the slow one. `instructions` that ask for a slow delivery,
and non-English text, drift the same way.

ElevenLabs is the opposite case: characters there are the *real* billing unit and exact, and it is
the dollars-per-credit that is unknowable here, because it depends on the subscription tier. Set
`MJ_ELEVENLABS_USD_PER_1K_CHARS` to have it priced; otherwise bill on the returned `credits`.

Published rates drift, so all of them are overridable: `MJ_OPENAI_TTS_USD_PER_MINUTE`,
`MJ_ELEVENLABS_USD_PER_1K_CHARS`. Unlike the camera costs — which are *measured* from Runware's
`includeCost` — these are quoted from published price lists and should be re-checked.

**`duration_seconds`** is returned regardless, and earns its place apart from billing: a comic
pairing a panel with a spoken line needs to know how long to hold the panel, and a lip-sync pass
needs the length before it can retime anything.

Measured with `ffprobe`, which needs a **seekable** source — so the in-memory bytes get a
short-lived temp file rather than a pipe. That is a ~50 KB probe-only write, not a round-trip of the
synthesis. A pipe was tried and is wrong twice over:

- ffprobe cannot get a duration out of a piped **Ogg** stream at all, reporting `N/A`, because the
  length lives in the last page's granule position and it cannot seek there. mp3 pipes fine; opus,
  the default here, never does.
- Piping bytes to a subprocess worked standalone and returned nil from inside the service's fiber
  for the same audio, where probing a path worked in both.

One trap if you ever re-test this: `ffprobe - < file` **succeeds** where a true pipe fails, because
shell redirection hands over a seekable file descriptor. Testing that way proves nothing about
piping — use `cat file | ffprobe -`.

## Qualifying a new camera

See **[techniques § Probing a model before you trust it](../techniques.md)**. Three checks, all
free, all catching things that are invisible once a service is running.
