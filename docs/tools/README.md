# mj tools — CLI reference

`mj <command> …`. Entry point `src/mj.cr`; run `mj` with no known command to see the usage line.
Most image commands need `RUNWARE_API_KEY` (read from the environment — source `.env` first, see
[setup](#setup)).

| Command | One-liner | Needs API? | Page |
| --- | --- | --- | --- |
| `mj init` | Scaffold a project (`.config/mj/config.yml`) | no | — |
| `mj serve` (or no arg) | Web server (Kemal) + Arcana bus on port **21683** | on use | [diorama](diorama.md) |
| `mj prop <name\|dir> [--rekey]` | Rough template → Nano render on solid bg → keyed transparent prop | yes (not `--rekey`) | [prop](prop.md) |
| `mj pixelize <dir> [--rekey]` | AI pixel-art restyle (8/16-bit), optional transparency + snap | yes (not `--rekey`) | [pixelize](pixelize.md) |
| `mj matte <image> […]` | Background removal, 3 tiers (procedural / IS-Net / Runware) | tier 3 only | [matte](matte.md) |
| `mj strip <dir> [out.png]` | Row of images → one long seamless panorama | yes | [strip](strip.md) |
| `mj base <dir> [strength]` | Template → plain structural master (Stage 1) | yes | [base & decorate](base-and-decorate.md) |
| `mj decorate <dir>` | Redraw a master decorated in a style/theme (Stage 2) | yes | [base & decorate](base-and-decorate.md) |
| `/cyclochroma` (web) | Key a colour out, light the transparency with music-reactive colour | no | [cyclochroma](cyclochroma.md) |
| `mj sfx <in.wav\|mp3> […]` | Reference sound → procedural Web Audio recipe (JSON) | no | [sfx](sfx.md) |
| `mj backdrop <image> [name]` | Import a full-frame image into the backdrop library | no | [diorama](diorama.md#backdrop-library) |
| `mj webp [<prop>] [--quality N]` | Transcode library deliverables to `.webp` | no | [diorama](diorama.md#webp) |
| `mj spend [--today\|--days N\|--all]` | Report the API cost ledger (per day / model / command) | no | [spend](spend.md) |
| `mj bus` | Join the Arcana bus, serve the image tools | yes | [bus](bus.md) |
| `mj version` | Print `mj <VERSION>` | no | — |

## Naming note

The project was renamed **minanime → mj** ("media jockey"). Module `MJ`, binary/config/bus all
`mj`; full product name `mjanime` (`github.com/trans/mjanime`). The local dir is still
`~/Projects/minanime` and some `examples/*.yml` / `notes/*.md` still say `minanime <cmd>` — read
those as `mj <cmd>`.

## Setup

```sh
mj init                       # once per project → .config/mj/config.yml
set -a; . ./.env; set +a      # load RUNWARE_API_KEY (the .env is bash syntax; shell is fish)
mj prop my-barrel             # …then run tools
```

- **Config** (`.config/mj/config.yml`): `data_dir`, `port` (default **21683**, from `cyclops-port
  mj`), and optional overrides for the three library roots. Env wins over config: `MJ_PROPS_DIR`,
  `MJ_BACKDROPS_DIR`, `MJ_SCENES_DIR`, `MJ_DATA_DIR`, `PORT`.
- **Libraries** live outside the repo under `~/.local/share/mj/` (XDG): `props/`, `backdrops/`,
  `scenes/`. See [prop library](prop.md#the-prop-library).
- **Keys**: `RUNWARE_API_KEY` (required for generation), `OPENAI_API_KEY` (TTS over the bus). Read
  straight from `ENV` — mj does not parse `.env` itself.
- **Cost**: every billed call prints its price and is appended to `~/.local/share/mj/spend.jsonl`
  (`$MJ_SPEND_LOG` relocates it, `MJ_SPEND_LOG=0` disables). See [spend](spend.md).
- **Bus**: opt out of the bus during `mj serve` with `MJ_BUS=0`. Bus URL from `ARCANA_WS_URL` /
  `ARCANA_URL`, default `ws://localhost:19118/bus`.

## Build

```sh
just build     # compiles the ONNX C shim (src/native/mjonnx.o) + the mj binary
./bin/mj …
```

`mj matte --isnet` (Tier 2) additionally needs `onnxruntime-cpu` and a protobuf-soname workaround —
see [matte](matte.md#tier-2--isnet-local-neural).
