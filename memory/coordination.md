# Coordination

*Updated 2026-10-15*

Who mj corresponds with, and what is open with each. The work itself is
tracked in the code repo's `TODO.md`; this note is only the who and the
state of the conversation.

## Our address

`@mj`, set as `handle: mj` in `../config.yml` on 2026-10-14. Before that
there was no `.ai/`, so the session hook fell back to the directory name
and registered `@minanime` (sessions run from the old symlink) or
`@mjanime`, while `@mj` was registered by hand. Every other project
writes to `@mj`. The bus services are separate addresses: `mj`,
`mj:camera`, `mj:voice`.

## Correspondents

- **`@datadungeon`**: picture prompts. mj sent the design (order, groups,
  `framing`, `light`, `changes`) to them, `@overlore` and `@owl` on
  2026-10-14 (`mail/sent/*-picture-prompt-design.md`; the note is
  `notes/picture-prompt-design-v1.md` at `f712770`), and `view.cr` for
  turning view and light into words (`mail/sent/*-view-words.md`). They
  answered 2026-10-15, after going through it with Thomas
  (`mail/received/20261015-003151Z-@datadungeon--re-picture-prompt-design-f58634bb.md`):
  `directives` replace `changes` and take the kind's own rules, so the
  fixed `rules` at the front are the same for every picture; a fixed rule
  must not contradict a description ("no text unless the description asks
  for it", Thomas); no kind setting, since the asset's type and the app's
  tag already say it; one migration, with each recipe recording its join
  order; `template` is Overlore's fill-in-the-blanks text, unrelated to
  prompts; DD takes `view.cr` in the release with the new order. The
  older `prompt_parts` request (`TODO.md`) is under review in that light.
  **0.14 built 2026-10-15** (`c76640e`, branch `0.14`, not tagged;
  `mail/received/20261015-164301Z-@datadungeon--datadungeon-0-14-8f1a5289.md`,
  sent to `@overlore` and `@owl`, copied to us): order rules · framing ·
  style · flavor · theme · subject · description · staging · light ·
  directives. `style` is now DataDungeon's own words for the art style;
  `flavor` (Thomas) is the app's wording refining it. A picture whose
  style isn't DataDungeon's isn't stored. mj's view words are in it as
  `ViewWords`. mj has no DataDungeon dependency, so nothing to bump here.
- **`@overlore`** (was `@infocomics`): asked for `shoot_batch`
  (2026-10-11, mainly because shots were drawn one at a time; concurrency
  fixed that the same day, `c7181a7`). **Parked by them** the same day,
  until they build a "can wait" lane for drawing ahead, which would suit
  Google's half-price batch endpoint (not used yet). Not built.
  **The Bard, head to toe, cut out** for overlore.xyz, asked 2026-10-15
  (`mail/received/*-@overlore--bard-full-figure-*.md`): three candidates
  made with `mj prop` (two fantasy poses, and the golden-style cartoon
  with its forest removed), each a prop dir in the project's
  `outtake/bard-full/`. Thomas then asked for more poses: two sets
  (fantasy, cartoon) of five, the cartoon bow in two takes picked 50/50.
  **Sent 2026-10-15** (`mail/sent/20261015-031922Z-@overlore--bard-poses.md`):
  the pictures and a `manifest.json` for Overlore's DataDungeon store in
  `outtake/bard-overlore/`. **Open:** Overlore's type and tags; whether
  the raw renders are kept, and as what (Thomas raised XCF, 2026-10-15).
- **`@cyclops`**: secrets and deploy conventions. Settled 2026-10-13; the
  repo `.env` stays until cyclops ships a fish export format, and it will
  ping when it does (`TODO.md`, "secrets / deploy").
- **`@arcana`**: the bus and arcana-core. Camera concurrency rides on
  arcana-core 0.17.1 (`c7181a7`).
