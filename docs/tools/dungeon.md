# `mj dungeon`: mj's own store

mj's own [DataDungeon](https://github.com/trans/datadungeon) store (Thomas, 2026-10-29: "your own
data dungeon"). It holds what Thomas needs to see or hear, with what mj measured of each, and
Thomas's answer once it's given. Thomas: "you can remove things, so don't be too worried about using
it for temporary storage", and "you don't need to store everything, just what you need me to see".
The originals stay where they were made (an outtake folder); the store keeps its own copy.

```
mj dungeon add <manifest.json>... [--free | --no-listen]
mj dungeon list [--answered | --all] [--json]
mj dungeon heard <id> yes|no [note...]
mj dungeon remove <id>...
```

- **`add`** files each entry of a manifest (below). It runs [`mj listen`](listen.md) on the speech:
  Whisper is loaded once for all of it, and Gemini 3.8 Flash runs too unless `--free` is given
  (about $0.0007 a take). `--no-listen` skips the checks. Filing the same bytes with the same traits
  again returns the same asset and refreshes its tracks, so a manifest can be run again. An entry
  with a `why` waits on Thomas, unless they have already answered it.
- **`list`** shows what waits on Thomas, grouped by piece; `--answered` shows their answers, and
  `--all` everything in the store.
- **`heard`** records Thomas's answer, given in chat for example. Yes rates the asset 1; no rates it
  -1 and flags it, which takes it out of play (DataDungeon's `get` skips it). The note goes with
  either.
- **`remove`** deletes assets from the store. Their files are deleted too, unless another asset holds
  the same bytes.

**Where:** `$MJ_DUNGEON_DIR`, else `$XDG_DATA_HOME/mj/dungeon`, else `~/.local/share/mj/dungeon`:
`dungeon.db` and `objects/` (each file named by its SHA-256). The consumer is `mj`.

## The page: `/dungeon`

`mj serve` shows the store at <http://localhost:21683/dungeon> (the Dungeon link in the nav).
Waiting items are grouped by piece. Each shows its words, why it waits, mj's listen findings and a
player, with **Yes** and **No** buttons and a note field. A highlighted finding is a glitch, or a
word both listeners heard differently ("worth a listen"). Answers are listed below the waiting
items.

## The manifest

A JSON array, one object per file:

| field | |
| --- | --- |
| `type` | `speech` or `effect` (DataDungeon's standard types; more as mj files them) |
| `file` | the sound: mp3, wav, ogg, flac or m4a |
| `traits` | the type's traits, below |
| `description` | the asset in words. Speech defaults to the `.txt` beside the take, with audio tags taken out |
| `generator` | what made it: `elevenlabs:eleven_v3` |
| `mouth`, `mouth_tool` | Rhubarb Lip Sync's JSON, kept as the `mouth` track (tool `rhubarb 1.14.0 --dialogFile` unless given) |
| `events`, `events_tool` | a JSON object of times in seconds, kept as the `events` track: every number, or list of numbers, is a cue named by its key (`shakes` → `shake`, `first_knock` → `first-knock`); `length` is skipped |
| `recipe` | `{form, settings, prompt, instructions, cost, cost_basis}`: how it was made, when it was one call |
| `why` | why Thomas should hear it. Without one, the asset is filed but doesn't wait on them |

Outtake `dungeon/import.py` wrote the first manifest. It held what waited for Thomas's ear on
2026-10-29: the landing tour's takes, the sung couplets, u-8b and the dice rolls.

## Types and traits

The traits are what mj looks things up by, most important first; the first is the group.

| type | traits | key, for example |
| --- | --- | --- |
| `speech` | piece, line, subtype, voice, accent | `speech.landing-tour.u-4.spoken.gerald.scottish` |
| `effect` | piece, sound | `effect.dice-roll.roll` |

- **`piece`:** the outtake folder it was made in: `landing-tour`, `bard-3`, `dice-roll`.
- **`subtype`:** `spoken` or `sung`. The sung couplets are speech: they're a Bard's lines, with
  mouth cues, though a lute plays under them.
- **`accent`:** `scottish`, or empty.
- **`take`:** every asset is also tagged with its file's name, without the extension
  (`tour-u-4-gerald-scottish`), though it isn't a trait.

## What's kept with each

- **Tracks:**
  - `listen`: the listen checks, each glitch over its time and each word note at its time. The tool
    names the listeners: `mj listen 0.13.4 (glitches, Whisper small.en, gemini-3.8-flash)`. A track
    with no cues means the checks ran and found nothing.
  - `mouth`: Rhubarb's cues.
  - `events`: a roll's shakes, throw, knocks and settle.
- **Links to the name `thomas`:**
  - `waiting-on`, while they haven't answered, with `{why, since}`;
  - `heard-by`, once they have, with `{answer, note, on}`.

Images aren't filed yet. When they are, they go in as TIFF masters
(`ImageMeta.new(compression: "normalize", target_format: "tiff")`: 8 bits a channel, lossless), and
the WebP is made from the master for serving.

`spec/dungeon_spec.cr` covers filing, the tracks, answers, filing again and removing.
