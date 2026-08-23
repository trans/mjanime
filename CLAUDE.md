# CLAUDE.md — mj (media jockey)

mj is a Crystal + Runware AI image/audio studio producing art for **Silicon Circus**, a boardwalk
game. Binary/module/bus = `mj` / `MJ` / `mj` (renamed from *minanime*; local dir still
`~/Projects/minanime`, full name `mjanime`). Old `examples/*.yml` / `notes/*.md` saying `minanime
<cmd>` mean `mj <cmd>`.

## Read the docs — they hold the hard-won lessons

The full wiki is in **[`docs/`](docs/README.md)** (this is the canonical knowledge home; `docs/api/`
is auto-generated Crystal API docs — leave it alone). Load the relevant page before doing that kind
of work:

- **[docs/world.md](docs/world.md)** — Silicon Circus + the day/night/pixel pipeline (why the art exists).
- **[docs/techniques.md](docs/techniques.md)** — pixel recipe, prop keying, night lighting, style-word bans, tiling, ImageMagick cheatsheet.
- **[docs/nano-banana.md](docs/nano-banana.md)** — the image model: versions, fixed dims, statelessness, prompt craft.
- **[docs/roadmap.md](docs/roadmap.md)** — Magic Themes (the goal), open problems, **working agreements**.
- **[docs/tools/](docs/tools/README.md)** — one page per `mj` command.

## Critical rules (do NOT violate)

1. **Never delete or overwrite the user's files without asking.** Delivered art, curated cutouts,
   `_*-backup` / `_*-prev` folders are off-limits; generated intermediates are fair game. Use a
   guarded whitelist when cleaning.
2. **Pixel art is DRAWN by the AI (`mj pixelize`, `snap:false`), never a procedural downscale.** If it
   looks photographic, the prompt under-stylized — strengthen the resolution cue; don't use `snap`.
3. **Night = projectors ON = radiant/floodlit**, not a dark night. Tightrope: too dark = "closed at
   3am", too bright = "daytime". See docs/techniques.
4. **Generate subjects as props on a solid bg** — don't matte complex scenes ("will never mess with
   background removal again").
5. **Report, don't judge** images — state files + objective params, let the user judge. **Try-and-SEE
   before rewriting a prompt.** **Lean prompts** (over-specifying drifts the concept & invents false
   signage).
6. **Nano Banana** = deterministic instruction-follower, **no cross-call memory**. Same words → same
   picture; change the WORDS for variety. `google:4@3` (NB2) is the default; avoid deprecated `4@1`.
   Fixed dim set (16:9 = `1376×768`, not `1344×768`).

## Layout & running

- Source: `src/mj.cr` (CLI dispatch), `src/engine/` (tools), `src/models/` (`*_spec.cr` = the YAML
  config schemas), `src/api/runware_client.cr`, `src/config.cr`, `src/diorama.cr`, `src/bus_service.cr`.
- Build: `just build` (compiles the ONNX C shim + binary). Run `./bin/mj …`.
- Keys from `ENV`: `set -a; . ./.env; set +a` first (the `.env` is bash; the shell is fish).
- Libraries live at `~/.local/share/mj/{props,backdrops,scenes}`. Web port **21683** (`cyclops-port
  mj`). Bus `ws://localhost:19118/bus` (opt out with `MJ_BUS=0`).
- **Finished venue art is in another repo:** `~/Projects/siliconcircus.lol/archive/media/boardwalk/
  used/venues/{real,pixel-32,pixel-16,pixel-8}/`.
- **Cost**: Runware is prepaid; every billed call prints `cost=$…` and is appended to
  `~/.local/share/mj/spend.jsonl`. `mj spend` reports it. Nano `google:4@3` ≈ **$0.069/image**, so
  prefer `--rekey` (free) when tuning. See [docs/tools/spend.md](docs/tools/spend.md).
- Loose ends: `TODO.md`. Long-form investigations: `notes/`.
