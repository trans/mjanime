# Coordination

*Updated 2026-10-16*

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
  **Proposal sent 2026-10-16** (`mail/sent/20261016-171751Z-@datadungeon--prompt-as-template.md`,
  worked out with Thomas, not copied to `@overlore` or `@owl`): one
  prompt with Mustache tags for the registered parts (rules, framing,
  style, flavor, theme, kind rules, character, light), each pinned to its
  wording and version when stored; the field order, `prompt_sent` and the
  custom case go away. No compression dictionary (Thomas). The thinking is
  in `notes/picture-prompt-design-v1.md`, "A prompt as a template".
  **Accepted 2026-10-16, after Thomas went through it with them**
  (`mail/received/20261016-174214Z-@datadungeon--re-proposal-prompt-as-template-97f4d8dc.md`):
  built in 0.14 before the tag, for every form (speech too), so the field
  orders go entirely. References are **full names**, not row ids (Thomas,
  with DD: ids save ~108 B a prompt; compression can come later). Bare
  tags wait for 0.15's standard `art-style`/`rating` tags; until then the
  app names the wording. **Light and view are plain words, not tags**: the
  app puts `ViewWords`' output in as its own text. A references table
  keeps `with_text` and `text.style=` (curio) indexed. Characters are
  named texts in field `character`; a literal `{{` is refused. DD's
  answers are "for you and Thomas to correct"; open: a naming rule for
  an app's rating wording (`overlore:g`?).
  **Sent 2026-10-16** (`mail/sent/20261016-191635Z-@datadungeon--wording-versions-as-hashes.md`,
  Thomas): a wording's version is numbered by each store (`put_named`,
  max+1), so `@2` can mean different words in two stores; proposed a
  version be the first 40 bits of SHA-256 of the exact words, Crockford
  base 32, 8 characters, every numbered version converted in 0.14.
  Thomas also thinks the rating's words may be universal rather than each
  app's (not sent; the vocabulary already calls the rating "the same in
  every app").
  **Accepted 2026-10-16**, after Thomas went through it with them
  (`mail/received/20261016-194736Z-@datadungeon--re-wording-versions-as-hashes-f3cbc3d8.md`):
  a version is the first 10 hex characters of the text's existing SHA-256
  (`texts.hash`), not base 32, so the store keeps one hash. Triggers
  refuse UPDATE/DELETE on a wording; a rename is a new name. Thomas
  decided: DataDungeon's owner is `dd`; standard styles stay `dd:`'s
  (custom ones would be the app's, e.g. `owl:kiddy-cartoon`); **style and
  flavor are one tag**, `{{style dd:silver-comic overlore:place}}`, pinned
  as `{{style dd:silver-comic@6e21dec2ab overlore:place@ad346239b4}}`, so
  a flavor's name is its purpose (`overlore:place`, filed under each
  style) and the `/purpose` part goes; DataDungeon's words take no purpose.
  Hex, not base 32, because everything else in DataDungeon is hex
  (Thomas with DataDungeon, 2026-10-16). Storing hashes as 32-byte blobs,
  hex only at the edges, is an open idea there, not scheduled: ~9% of
  Overlore's store, half of it a `content_hash` tag that goes in 0.15
  (their `memory/performance.md`). Thomas, 2026-10-16: worth doing for all
  hash fields; 4% at 10,000,000 assets is not nothing.
  Thomas, 2026-10-16, sent the same day (`mail/sent/20261016-203838Z-@datadungeon--flavor-answers.md`,
  with his view that a rating's words are `dd:`'s, not decided): a style with no
  wording of the named flavor falls back to DataDungeon's words alone;
  one flavor per tag (another refinement is another flavor name, e.g.
  `place-cave`); a change to a standard wording needn't be announced,
  since it will only ever refine.
  **Ratings settled 2026-10-16** (Thomas with DataDungeon,
  `mail/received/20261016-204705Z-@datadungeon--re-wording-versions-as-hashes-350e88c5.md`):
  one wording per rating, DataDungeon's (`dd:g`, `dd:pg`, `dd:r`, `dd:x`),
  shared by text and pictures and worded as what's suitable, not what's
  forbidden; speech gets
  none, since the rating applies when its text is written.
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
  **Mouths and blinks for the Bard**, asked 2026-10-16
  (`mail/received/20261016-221432Z-@overlore--bard-mouths-and-blinks-be6adc02.md`):
  Rhubarb Lip Sync gives the timing (Thomas checked it); they want mouth
  patches X, A-F (G, H optional) for beckon, present, play and write in
  both sets, and closed (and half-closed) eyes for all 11 poses, each a
  cropped patch with alpha that lines up exactly with its cut-out in
  `outtake/bard-overlore/`, plus a manifest of pose, shape, size and x, y.
  A trial first: present in both sets. **Patches dropped** (Thomas, 2026-10-16:
  a wide mouth moves the jaw, so pasted patches never meet the face's lines);
  head swaps between poses also dropped (placement needs a person every
  time). Each mouth is now a whole-picture edit of the pose's render (trial
  in `outtake/bard-mouths/`, 10 edits, $0.692: no shift in 9 of 10, ~3.5/255
  change outside the face). Asked them 2026-10-17
  (`mail/sent/20261017-020413Z-@overlore--bard-mouths-audio.md`) for a spoken
  and a sung Bard clip with Rhubarb's cues, for a preview page here.
- **`@cyclops`**: secrets and deploy conventions. Settled 2026-10-13; the
  repo `.env` stays until cyclops ships a fish export format, and it will
  ping when it does (`TODO.md`, "secrets / deploy").
- **`@arcana`**: the bus and arcana-core. Camera concurrency rides on
  arcana-core 0.17.1 (`c7181a7`).
