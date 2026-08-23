# `mj spend` — the API cost ledger

Runware is **prepaid**: you buy credits, they run the models, every task debits your balance. mj
now asks for the price of each task (`includeCost`), prints it as it happens, tallies the run, and
appends a row to a persistent ledger so spend is visible after the fact.

```
mj spend [--today | --days N | --all] [--json]
```

Default window is the last 30 days.

## What you see while working

Every billed call logs its own price and the running total for the process:

```
[runware] Edit(refs=1): model=google:4@3 1024x1024
[runware] Result: imageUUID=4f27c566-… cost=$0.0692 (run $0.0692)
[prop] wrote …/render.png and …/prop.png
[spend] 1 call this run — $0.0692, today $0.0698
```

The `[spend]` line prints once, on exit, from any command that made a billed call — so a long
`mj cyclorama --steps 8` ends with the total for the whole roll-out.

## The ledger

One JSON object per line, appended at `$XDG_DATA_HOME/mj/spend.jsonl` (i.e.
`~/.local/share/mj/spend.jsonl`):

```json
{"t":"2026-08-22T15:47:29Z","cmd":"prop","provider":"runware","task":"edit","model":"google:4@3","cost":0.0692,"w":1024,"h":1024}
```

- `cmd` — the mj subcommand that spent it, so cost is attributable per tool.
- `task` — `imageInference` / `inpaint` / `edit` / `backgroundRemoval`.
- `cost` — USD, **or `null`** if the API reported no price. Unpriced calls are counted separately
  and never silently treated as free.
- `$MJ_SPEND_LOG` relocates the file; `MJ_SPEND_LOG=0` disables writing it (the run tally still
  prints).

## Reports

```sh
mj spend                 # last 30 days: by day, by model, by command, grand total
mj spend --today
mj spend --days 7
mj spend --all
mj spend --all --json    # same numbers, machine-readable
```

```
By model
  google:4@3                   6 calls      $0.4152
  default                      1 call       $0.0006

TOTAL  7 calls  $0.4158
```

## What things cost

Measured, not quoted — read your own ledger for current numbers:

| Task | Model | Observed |
| --- | --- | --- |
| `edit` (prop / pixelize / decorate / cyclorama) | `google:4@3` (Nano Banana 2) | **$0.0692** / image |
| `backgroundRemoval` (`mj matte --runware`) | Runware default | **$0.0006** / image |

**Free** (no API call, so no cost): `mj prop --rekey`, `mj pixelize --rekey`, `mj matte` Tier 1/2,
`mj webp`, `mj backdrop`, `mj sfx`. When you're tuning a key, `--rekey` is the whole point — the
render is already paid for.

## Topping up

Runware is not BYOK — you are not plugging a Google key into mj; Runware resells the inference and
bills your account. Buy credits in the Runware dashboard (Billing → credits, and an auto-recharge
threshold if you'd rather not run dry mid-session). `RUNWARE_API_KEY` does not change when you top
up, so nothing in `.env` needs touching.

---
Related: [tools index](README.md) · [Nano Banana](../nano-banana.md) · [prop](prop.md) ·
[matte](matte.md)
