# mj — media jockey

An AI image & audio studio in Crystal, built on [Runware](https://runware.ai). mj produces the art
for **Silicon Circus**, a boardwalk game: transparent props, AI pixel-art, background matting,
seamless scenery panoramas, parallax dioramas, and procedural sound effects.

> Formerly *minanime*. Module `MJ`, binary/config/bus `mj`, full name `mjanime`.

## Tools

| Command | What it does |
| --- | --- |
| `mj prop <name>` | Rough sketch → AI render on a solid bg → **keyed transparent prop** |
| `mj pixelize <dir>` | AI **pixel-art** restyle (8/16-bit), optional transparency |
| `mj matte <image>` | **Background removal** — procedural / IS-Net / Runware tiers |
| `mj strip <dir>` | Row of images → one long **seamless panorama** |
| `mj base` / `mj decorate` | Template → structural master → styled variation |
| `mj sfx <in.wav>` | Reference sound → procedural **Web Audio recipe** |
| `mj serve` | Web app (editor + **Diorama** parallax player) on port 21683 |
| `mj bus` | Serve the image tools on the **Arcana** bus |

Full CLI reference: **[docs/tools/](docs/tools/README.md)**.

## Documentation

The **[`docs/`](docs/README.md)** wiki covers the tools, the techniques, and the world:

- **[The World](docs/world.md)** — Silicon Circus and the day/night/pixel pipeline.
- **[Techniques & lessons](docs/techniques.md)** — the pixel recipe, prop keying, night lighting,
  prompt craft. The hard-won craft.
- **[Nano Banana](docs/nano-banana.md)** — the image model mj leans on.
- **[Roadmap](docs/roadmap.md)** — goals, open problems, working agreements.

(`docs/api/` holds the auto-generated Crystal API docs via `crystal docs`.)

## Getting started

```sh
shards install
just build                     # compiles the ONNX C shim + the mj binary
mj init                        # scaffolds .config/mj/config.yml
set -a; . ./.env; set +a       # load RUNWARE_API_KEY (the .env is bash; shell may be fish)
mj prop my-barrel              # …run a tool
```

- **Requires** `RUNWARE_API_KEY` for image generation (`OPENAI_API_KEY` for bus TTS). Some tools also
  use ImageMagick, and `mj matte --isnet` uses `onnxruntime-cpu` (see [matte docs](docs/tools/matte.md)).
- **Libraries** (props, backdrops, scenes) live under `~/.local/share/mj/`.

## Development

- Source: `src/mj.cr` (CLI), `src/engine/` (tools), `src/models/*_spec.cr` (YAML config schemas),
  `src/api/`, `src/diorama.cr`, `src/bus_service.cr`.
- `just build` / `just` recipes; specs under `spec/`.
- Contributor & agent notes: **[CLAUDE.md](CLAUDE.md)**. Loose ends: `TODO.md`.

## License

MIT — Thomas Sawyer.
