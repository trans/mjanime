# Coordination

*Updated 2026-10-17*

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
  **0.14 rebuilt 2026-10-17, superseding both the fields and the template**
  (`4426581`, branch `0.14`, not tagged;
  `mail/received/20261017-035601Z-@datadungeon--datadungeon-0-14-simplified-faefa8b6.md`).
  A review found the prompt model redesigned four times in three days, and
  on Overlore's store the fields took more room than plain prompts (426 KB
  against 295 KB). Thomas chose, 2026-10-16: `prompt:` is exactly what the
  provider was sent; `instructions:` is speech's and chat's second input;
  `wordings:` lists the named wordings in it (`Recipe.wording(kind,
  "owner:name[/purpose]", words)`, kind free), each versioned by the
  10-hex hash and checked word for word against the prompt when stored. A
  picture's style is `dd:`'s (`db.style_text`), and an app's own words are a
  `flavor` named for the style (`overlore:silver-comic/place`), so the
  one-tag `{{style ...}}` form is gone with the template. The order of parts
  is advice in DD's README. One owner per store (sharing = copying, with
  `copied-from`); MatchIndex, per-app indexes, views, light and keyframes
  frozen; uses, owner tags and refusing to delete what's in use dropped; the
  hub deferred. DD's mail says mj is pinned to `~> 0.13.x`, but mj has no
  DataDungeon dependency (`shard.yml`), so nothing to bump. DD
  says the rating's words still wait for Thomas. The blob idea is noted
  there for later.
  **Tagged v0.14.0 2026-10-17** (`401dd4a`, on `main`;
  `mail/received/20261017-185356Z-@datadungeon--datadungeon-v0-14-0-is-tagged-8e82f4ca.md`),
  with two changes before the tag (Thomas, 2026-10-17;
  `mail/received/20261017-165102Z-*-1a8b718e.md`, `-175715Z-*-3591c9a9.md`):
  **no standard styles.** Each app names, words and tags its own
  (`overlore:silver-comic`, kind `style`), so `dd:`'s art styles,
  `db.style_text` and flavor are gone, superseding the style lines above.
  The vocabulary keeps only the ratings (`db.rating_text("pg")`, `dd:pg`).
  A wording's `/purpose` is deprecated, and a later release removes it.
  New: `db.add_wordings(id, wordings)` names words a stored recipe was sent
  but didn't name. Styles shared between apps fall to the hub, later. A
  store's first read-write open converts it one way, so back it up first.
  mj's own store (`TODO.md`) was waiting for this tag; mj would name its
  own styles.
  **v0.15.0 tagged 2026-10-17** (`58f1fa6`, a cleanup;
  `mail/received/20261017-224314Z-@datadungeon--datadungeon-v0-15-0-is-tagged-5a81fe4f.md`):
  wording names are `owner:name[@version]`, a `/` refused; `recipe_fields`
  dropped; stores from before 0.12 must go through 0.14 first. Nothing for
  mj, which has no DataDungeon dependency; its own store would start on it.
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
  **They answered 2026-10-17**: all nine lines with Rhubarb's cues in
  `~/Projects/overlore/outtake/bard-lips/clips/` (`a-2` spoken, in present;
  `c-1` verse spoken in rhythm, in play; drive frames from the audio's
  `currentTime`, the page plays at 1.05x). Rhubarb is the v1.14.0 release
  zip run as it comes, not installed. They asked for a sung take with
  ElevenLabs (v3 `[sings]` or Eleven Music). Thomas then put a scoped
  ElevenLabs key in cyclops-env for mj (TTS, voices, similar voices, music;
  not `user_read` or `audio_isolation`). Takes in the project's
  `outtake/bard-sung/`, with a preview at `outtake/bard-preview/`
  (`mail/sent/20261017-023932Z-@overlore--sung-takes.md`). `[sings]` only
  makes v3 lull; Eleven Music sings but takes no voice id.
  **Thomas's voice decisions, 2026-10-17** (sent in
  `mail/sent/20261017-034920Z-@overlore--bard-poses-per-line.md`): offer
  both, Henry (`KP6QbSvtyKSTfuh4UzcQ`) at 1.1x and the British Football
  Announcer (`gU0LNdkMOQCOrPrwtbee`) at 1.0x, chosen by the visitor with
  comedy and tragedy masks or at random; songs from Eleven Music in each
  voice's manner, Henry's preferred. Pitch-shifting Henry was rejected
  ("elf").
  **Their answers, 2026-10-17**
  (`mail/received/20261017-041802Z-@overlore--re-bard-pose-per-line-32e438b7.md`,
  `mail/received/20261017-045215Z-@overlore--bard-frames-gaze-and-count-366a21aa.md`,
  the second agreed with Thomas): one pose per line, never changing partway:
  beckon a-1, b-1; present a-2, b-2; play c-1, c-2 (sung, strumming); write
  a-3, b-3, c-3. Bows are silent. Mouths A, B, C, D, F for those four poses
  in both sets (40); one set serves both voices. The realistic Bard first
  gets new poses looking at the visitor (beckon, present, play; write
  glancing up), then cut-outs, then mouths; the cartoon is fine as it is.
  Inbetweens with the closed mouth only: 5 realistic, 8 cartoon. Blinks
  wait. About 75 frames; a visitor loads about 20 (talk a or b) or 25 (c).
  c-3 to be tried sung and spoken (Thomas). Strumming (Thomas, 2026-10-17):
  the strum keeps its own tempo, so each strum position gets all five
  mouths; Nano moves the hand a long way or not at all, so the positions
  are still being worked on. They asked that `mj:voice` get the ElevenLabs
  key, `eleven_v3` and Eleven Music. **Key live 2026-10-17** (`just
  env-pull` from cyclops, service restarted; Thomas asked): `speak` with
  `provider: elevenlabs`, `model: eleven_v3` works, though `voices` lists
  models only to v2.5 (arcana-ai's list). Told them, with the frames so far
  (`mail/sent/20261017-062622Z-@overlore--elevenlabs-in-mj-voice-and-frames.md`).
  Thomas then widened the key's permissions (same key; `user_read` works
  now), and `mj:voice` got a `music` tool (Eleven Music) and lists
  `eleven_v3` (committed `605031a`); told them the same day
  (`mail/sent/*-@overlore--music-in-mj-voice.md`).
  **Talking frames delivered 2026-10-18** (Thomas: deliver what's done, so
  the site can run talks while strums and inbetweens come;
  `mail/sent/20261018-010830Z-@overlore--bard-talking-frames.md`): 40 mouth
  frames and the 3 bows in `outtake/bard-overlore-frames/` with
  `manifest.json` (made by its `build.py`). Each frame keeps its offset in
  the 848x1264 render; a pose's mouths share one crop; recipes give
  `prompt` as sent. Also told them `credits` became `billed_characters`
  and `usd`. **In their landing page** (`be55b4a` there, not deployed;
  `mail/received/20261018-011555Z-@overlore--re-the-bard-s-talking-frames-in-the-page-70e792e9.md`):
  poses at their offsets on the 848x1264 stage, mouths stacked in place,
  cues from our `bard-preview/` Rhubarb runs; checked in headless Chromium.
  Pose changes are cuts and the song plays in the still play pose until
  strums and inbetweens come. **Voices and song delivered 2026-10-18**
  (Thomas: off the old OpenAI voice; `mail/sent/20261018-021441Z-@overlore--bard-voices-and-song.md`):
  all nine lines in Henry (1.1x) and the Announcer, eleven_v3, and c-1+c-2
  sung as one song plus c-3 sung, with cues, in `outtake/bard-overlore-voice/`.
  **Thomas's notes, 2026-10-18:** the closed "m" mouth reads as cross at
  rest and at the end (a resting smile X was made for every pose); the
  cartoon's eyes were closed in every play frame (open-eyed play mouths
  made, strum hands pasted on); the body must move while he talks (head and
  body to be split into layers: heads carry mouths, bodies carry strums and
  gestures; a marionette sway is in mj's preview); the realistic Bard
  smiles on some syllables (later). None of this delivered yet.
  **Voices and song in their page** (`0ba1b7f` there, not deployed;
  `mail/received/20261018-024740Z-@overlore--re-the-bard-s-elevenlabs-voices-and-his-song-in-th-4df579f9.md`):
  Henry or the Announcer at random, recorded at signup; talk c plays the
  c1c2 song, bow, email, then c-3 (sung by default, `?c3=spoken`); all
  takes evened to -18 LUFS. Frames now go on a canvas, each pose's frames
  decoded up front (stacked images blinked black for Thomas), so new
  frames need only the same naming and offsets. Thomas prefers song #28
  (the first c-1 take) to the c1c2 song (#32); extending #28 with c-2 is
  proposed, not started. **Cartoon first** (Thomas, 2026-10-18): get the
  cartoon Bard working, then consider the realistic one. Gestures for the
  cartoon's beckon, present and write are made (Nano edits of the arm, the
  talking heads pasted on, `outtake/bard-gesture/`), cycled while he talks
  (present 1, 3, 2, 3 is Thomas's come-hither). No crossfades (Thomas).
  **Entrance gag asked 2026-10-18** (Thomas's idea, via `@overlore`,
  `mail/received/20261018-032817Z-@overlore--a-gag-entrance-for-the-cartoon-bard-a-bush-a-caugh-cf132693.md`):
  the cartoon Bard behind a bush (whistling, a stream, a zip), sliding out
  wide-eyed. Wanted: a bush cut-out in his style (taller and wider than
  him, set to his right as seen), a "caught" frame on the 848x1264 stage
  (wide-eyed, mouth closed or a small o, hands at his belt), a sidling
  frame if easy, and three sounds (whistled tune 3-4 s, water stream 3-4 s
  that stops cleanly, a zipper ~0.5 s). **Open.**
  **Moves between poses** (Thomas, 2026-10-18: each pose has its gesture
  group but nothing joins them). Chained Nano edits failed (a second lute,
  doubled quills; the write pose itself had two quills, now mended in every
  write frame). A first-and-last-frame video (LTX-2.5 Pro on Runware,
  present -> write, $0.72) keyed cleanly and, scaled back onto the stage,
  matches both poses to 1 px (`outtake/bard-move-video/`).
  **Open:** strum positions (Thomas, 2026-10-18: the poses are
  close, and only the hand just above the strings is missing; his wording,
  "touching the strings, most of the hand above them", left the hand in
  place on both sets, `outtake/bard-strum/prompt.txt`); inbetweens.
- **`@cyclops`**: secrets and deploy conventions. Settled 2026-10-13; the
  repo `.env` stays until cyclops ships a fish export format, and it will
  ping when it does (`TODO.md`, "secrets / deploy").
- **`@arcana`**: the bus, arcana-core and arcana-ai (now under
  `~/Projects/Arcana/`). Camera concurrency rides on arcana-core 0.17.1
  (`c7181a7`). **Asked 2026-10-17** (Thomas;
  `mail/sent/20261017-193239Z-@arcana--elevenlabs-credits-header.md`): have
  arcana-ai's ElevenLabs speech report the credits charged, from the
  `character-cost` header (eleven_v3: 12 for 30 characters, where mj's table
  said 1.0 a character). Until then mj:voice reads it by overriding the
  private `ElevenLabs#post_api` in a subclass (`37aa35d`), to drop once
  arcana-ai has it; mj is on arcana-ai 0.3.0 and said it would move up for it.
  **Answered: arcana-ai 0.5.5** (2026-10-17, correcting 0.5.4;
  `mail/received/20261017-211900Z-@arcana--arcana-ai-0.5.5-characters-not-credits-031f269a.md`).
  @arcana reads ElevenLabs' API price page as billing API use in dollars per
  character, one rate per model on every plan, so the header is the
  characters billed, not credits: `result.usage.characters`, and
  `result.cost` prices it with no table of ours ($0.08 per 1,000 for
  eleven_v4, eleven_v3, eleven_multilingual_v2; $0.04 for eleven_v4_turbo,
  eleven_v3_conversational, Flash and Turbo; checked 2026-10-17), so the
  test line is $0.00096. **Moved to 0.5.5** (Thomas, 2026-10-17; fixed, not
  yet committed): the override is gone, mj:voice returns `billed_characters`
  (was `credits`, in music too) and `usd` from arcana-ai, exact; OpenAI stays
  on mj's own `TtsRates`, since arcana-ai gets OpenAI's usage only on a
  streamed reply. **Open:** @arcana's question, whether the account counts that line at 12 (the
  header) or 30 (the text). The ElevenLabs key lacks
  `speech_history_read`, so the history API can't answer it (2026-10-17).
