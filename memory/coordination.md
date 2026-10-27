# Coordination

*Updated 2026-10-27*

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

- **`@datadungeon`**: notices to every app go to the Arcana topic
  `#datadungeon` (Thomas, 2026-10-19,
  `mail/received/20261019-215533Z-@datadungeon--*`); requests to one app
  still come as mail. Not subscribed (Thomas: later), so read it on "check
  mail": **read through post 8** (2026-10-21). Post 1, v0.15.2: the standard asset types,
  `subtype`, and `automaton` (the Bard graph); stores move onto the types
  one at a time, Overlore last. Post 2, v0.15.3: a take's tracks,
  `words` and `mouth` (`{start_ms, end_ms, value}` cues, naming the tool),
  which mj:voice's word times could feed (`TODO.md`). Posts 3-5,
  v0.15.4-6: TIFF masters, deleting a transcript, `map` renamed `pass`.
  Post 6, v0.15.7: search by meaning (a type names what's embedded).
  Post 7, v0.16.0: only standard type names. Post 8, v0.16.1: prop and
  figure reworded (a building's front is a prop), and characters as assets
  are on DataDungeon's to-do list (Thomas), how still open. mj has no DataDungeon
  dependency, so none of these needs anything here.
  Picture prompts. mj sent the design (order, groups,
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
  **Grey canvas fixed** (Thomas asked, 2026-10-19, `f5f3bc6`): Runware
  shots with no reference are text-to-image now, not an edit of a flat
  grey canvas (its grey survived as a sky on `klein`, which draws
  Overlore's rooms). `bin/mj-arcana` rebuilt and the service restarted
  20:10Z; checked through the live bus. Told Overlore, and asked about
  27 doubled ElevenLabs takes in the account's history since 2026-10-17
  (mostly 2026-10-18 16:54-17:42Z, the pitch; about $0.44; route unknown,
  mj's service log has nothing then)
  (`mail/sent/20261019-201106Z-@overlore--mj-camera-*`, `…201130Z-*`).
  **Answered** (`mail/received/20261019-202608Z-@overlore--re-the-doubled-takes-*`
  and two corrections after it): all Overlore's, through mj:voice, from its
  bus client's address `overlore` (no @); about 16 of the 27 are takes on
  purpose (two voices, or two takes to choose from) or the same length with
  different text, one a real repeat. The rest, if any, could only be the
  game started for mj:voice and ElevenLabs. Thomas decided the same day
  that each voice names its own provider, so the game's provider switch is
  going. Settled; nothing to do.
  **mj:voice's OpenAI side** (Overlore, 2026-10-19,
  `mail/received/20261019-212307Z-@overlore--mj-voice-s-openai-*`): calls
  took 30-76 s at 21:16-21:21Z, and the dated gpt-4o-mini-tts-2025-12-15
  (pinned so a voice doesn't drift) got no `usd`. Timed 22:14-22:19Z: 1.8-6.9 s
  direct, 1.2-5.3 s through mj:voice, so the slowness was OpenAI's at the
  time. **Fixed in `4a4cbe0`:** mj:voice takes OpenAI's price from
  arcana-ai (the tokens its event stream reports; a dated snapshot at its
  model's rates), exact, with TtsRates only as the fallback; service rebuilt
  and restarted 22:18Z (old binary kept as `bin/mj-arcana.prev`), checked
  over the bus. Clip length varies take to take (2.9-6.6 s for four words),
  mostly in pauses. Told them
  (`mail/sent/20261019-221942Z-@overlore--re-mj-voice-s-openai-*`, with two
  corrections of my test calls' times and count after it).
  **Timeouts and ElevenLabs speed** (Overlore, 2026-10-21,
  `mail/received/20261021-153733Z-@overlore--mj-voice-times-out-*`): every
  dated-snapshot `speak` failed "Read timed out" at 60 s, 14:05-14:35Z;
  Overlore pins it for its narrators (moving to ElevenLabs anyway).
  Direct, 15:43-15:48Z: dated and unpinned both 65-81 s for a 4-5 s clip,
  and with events OpenAI sends nothing until done, so arcana-ai's fixed
  60 s read timeout fails it. `speed` on ElevenLabs: v2 honours it (4.83 s
  to 3.82 s at 1.2), eleven_v3 ignores it; arcana-ai doesn't send it
  anyway. Told them (`mail/sent/20261021-155036Z-*`). **Asked @arcana**
  (Thomas approved, 2026-10-21; `mail/sent/20261021-161230Z-@arcana--*`);
  **fixed in arcana-ai 0.6.1**, mj on it (see `@arcana` below).
  **The Bard, head to toe, cut out** for overlore.xyz, asked 2026-10-15
  (`mail/received/*-@overlore--bard-full-figure-*.md`): three candidates
  made with `mj prop` (two fantasy poses, and the golden-style cartoon
  with its forest removed), each a prop dir in the project's
  `Outtake/bard-1-2/full/`. Thomas then asked for more poses: two sets
  (fantasy, cartoon) of five, the cartoon bow in two takes picked 50/50.
  **Sent 2026-10-15** (`mail/sent/20261015-031922Z-@overlore--bard-poses.md`):
  the pictures and a `manifest.json` for Overlore's DataDungeon store in
  `Outtake/bard-1-2/overlore/`. **Open:** Overlore's type and tags; whether
  the raw renders are kept, and as what (Thomas raised XCF, 2026-10-15).
  **Mouths and blinks for the Bard**, asked 2026-10-16
  (`mail/received/20261016-221432Z-@overlore--bard-mouths-and-blinks-be6adc02.md`):
  Rhubarb Lip Sync gives the timing (Thomas checked it); they want mouth
  patches X, A-F (G, H optional) for beckon, present, play and write in
  both sets, and closed (and half-closed) eyes for all 11 poses, each a
  cropped patch with alpha that lines up exactly with its cut-out in
  `Outtake/bard-1-2/overlore/`, plus a manifest of pose, shape, size and x, y.
  A trial first: present in both sets. **Patches dropped** (Thomas, 2026-10-16:
  a wide mouth moves the jaw, so pasted patches never meet the face's lines);
  head swaps between poses also dropped (placement needs a person every
  time). Each mouth is now a whole-picture edit of the pose's render (trial
  in `Outtake/bard-1-2/mouths/`, 10 edits, $0.692: no shift in 9 of 10, ~3.5/255
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
  `Outtake/bard-1-2/sung/`, with a preview at `Outtake/bard-1-2/preview/`
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
  frames and the 3 bows in `Outtake/bard-1-2/overlore-frames/` with
  `manifest.json` (made by its `build.py`). Each frame keeps its offset in
  the 848x1264 render; a pose's mouths share one crop; recipes give
  `prompt` as sent. Also told them `credits` became `billed_characters`
  and `usd`. **In their landing page** (`be55b4a` there, not deployed;
  `mail/received/20261018-011555Z-@overlore--re-the-bard-s-talking-frames-in-the-page-70e792e9.md`):
  poses at their offsets on the 848x1264 stage, mouths stacked in place,
  cues from our `bard-1-2/preview/` Rhubarb runs; checked in headless Chromium.
  Pose changes are cuts and the song plays in the still play pose until
  strums and inbetweens come. **Voices and song delivered 2026-10-18**
  (Thomas: off the old OpenAI voice; `mail/sent/20261018-021441Z-@overlore--bard-voices-and-song.md`):
  all nine lines in Henry (1.1x) and the Announcer, eleven_v3, and c-1+c-2
  sung as one song plus c-3 sung, with cues, in `Outtake/bard-1-2/overlore-voice/`.
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
  talking heads pasted on, `Outtake/bard-1-2/gesture/`), cycled while he talks
  (present 1, 3, 2, 3 is Thomas's come-hither). No crossfades (Thomas).
  **Entrance gag asked 2026-10-18** (Thomas's idea, via `@overlore`,
  `mail/received/20261018-032817Z-@overlore--a-gag-entrance-for-the-cartoon-bard-a-bush-a-caugh-cf132693.md`):
  the cartoon Bard behind a bush (whistling, a stream, a zip), sliding out
  wide-eyed. Wanted: a bush cut-out in his style (taller and wider than
  him, set to his right as seen), a "caught" frame on the 848x1264 stage
  (wide-eyed, mouth closed or a small o, hands at his belt), a sidling
  frame if easy, and three sounds (whistled tune 3-4 s, water stream 3-4 s
  that stops cleanly, a zipper ~0.5 s). **Reworked by Thomas the same day**
  (`mail/received/20261018-042818Z-@overlore--re-the-bush-gag-changed-no-stream-or-zip-a476471c.md`):
  the bush rises where he'll stand, whistling, the visitor types "> Hello."
  and the whistling stops dead, "Huh?" (Thomas records it), the bush slides
  away left. Still wanted: the bush (his height plus a bit, wider than him,
  hiding feathers and lute), the caught frame, a whistled tune 3-4 s that
  can be cut mid-phrase. Dropped: the stream, the zip, the sidling frame.
  A landscape rising from below is for later. **Corrected the same day**
  (`mail/received/20261018-044621Z-@overlore--re-the-bush-gag-the-stream-and-zip-are-back-in-sor-b7929c3d.md`):
  the stream and the zip are back in (they say what he was doing). Order:
  whistling and the stream; "> Hello." and both stop dead; "Huh?"; the zip;
  the bush slides left and he's caught. Wanted: the bush, the caught frame,
  and three sounds: the whistle (loops while the prompt waits, or cuts
  mid-phrase), the stream (loops, stops dead), the zip (~0.5 s). No sidling
  frame. **Closed 2026-10-25** (@overlore): all three are in the 3D act. The
  whistle and zip are its stand-ins (Trans: fine); the stream is a CC0
  freesound recording Trans picked.
  **Moves between poses** (Thomas, 2026-10-18: each pose has its gesture
  group but nothing joins them). Chained Nano edits failed (a second lute,
  doubled quills; the write pose itself had two quills, now mended in every
  write frame). A first-and-last-frame video (LTX-2.5 Pro on Runware,
  present -> write, $0.72) keyed cleanly and, scaled back onto the stage,
  matches both poses to 1 px (`Outtake/bard-2/move-video/`). **Rejected** by
  Thomas after a second take ("the video is awful, far too many issues"):
  no video moves; poses cut. Lesson: inspect generated frames at full size,
  frame by frame, before showing them; a contact sheet hid the errors.
  **Animation state graph built 2026-10-18** (Thomas's idea: a graph of
  acceptable paths, walked in a variety of ways): `Outtake/bard-1-2/graph/
  graph.yml` (body nodes by frame folder, groups, weighted edges, a walk
  rule per pose: cycle / random / beat / pause / hold, moves between poses)
  and `graph.py` (checks frames exist, compiles neighbour lists, applies the
  flipbook's unusable marks). Mouths are a separate layer chosen by the
  cues, not graph nodes. mj's preview is now driven by it (`bard-1-2/preview/
  build.py`). Next if wanted: the flipbook editing links and groups; then
  Overlore playing the same compiled graph. **Graph and walker delivered**
  the same day (`Outtake/bard-1-2/overlore-graph/`: graph.json with a frame
  table, frames/, bard-walker.js; `mail/sent/20261018-071956Z-@overlore--bard-animation-graph.md`).
  **The song for talk c** (Thomas approved, 2026-10-18): song #28's verse
  with c-2 added in its style (`Outtake/bard-1-2/sung/take-music-28c2c.mp3`,
  made by uploading #28 and inpainting with music_v2_5; c-2's words
  changed to Overlore's "Soon, soon! So tell me where to send / a letter to
  an early friend"; he sings "Soon!" once, kept). Sent with the re-recorded
  spoken c-2 (`mail/sent/20261018-074744Z-@overlore--the-song-for-talk-c.md`).
  **Final: `take-music-28c2d`** (Thomas: "perfect"): the second "soon"
  spliced back in from a copy of the sung word (`Outtake/bard-1-2/sung/soonsoon.py`),
  so c-2's words stand in full; sent as a correction
  (`mail/sent/20261018-081211Z-@overlore--the-song-for-talk-c-final.md`).
  **Which Bard where** (Thomas, 2026-10-18): the realistic Bard does the
  salesman pitch, the cartoon Bard the song (landing page, talk c).
  **Salesman poses, first batch made** (2026-10-18, Thomas: "I trust you";
  `Outtake/bard-1/pitch/`, flipbook #324-353, $0.83): a base (`fantasy-base`,
  from the mended write pose: hands free, looking at the viewer, lute
  behind his hip) with its six mouths ("oo" redone: the first frowned,
  kept as `fantasy-base-F-frown`), and pointing, arms spread and finger up,
  arm-only edits of the base with its heads pasted on by `compose.py`
  (spread's neck taken off by a box patch; the full no-neck edit turned
  the lute round). Thomas: all usable but #353 (the turned lute).
  **Second batch made** the same day (flipbook #354-412, $0.76): counting
  two and three (from finger up, which is "one"), robot arms (sideways,
  redone once: the first lost the lute), patting the lute, minding the
  lute (hugged in front), hand on heart (redone: the first lost the
  lute), the secret hand (laid over the heads), thumbs-up (the wink's
  body under the talking heads) and the wink (its own frame). `compose.py`
  now keeps only the moving face from the heads (a head box left a seam
  across his throat). All in `bard-1-2/graph/graph.yml` (realistic set, a
  pose each; counting walks one-two-three at pauses: the walker's and the
  preview's "pause" rule now takes an `order`). **Waiting on Thomas** to
  look. Thomas: patting the lute out (#384-390, no neck), robot "fine,
  we'll see how it plays". **Sent** the same day: the rebuilt graph
  package (`Outtake/bard-1-2/overlore-graph/`, 226 frames) with a pose for
  each line (`mail/sent/20261018-225627Z-@overlore--salesman-pitch-poses.md`);
  present left out of the map until Thomas clears its marks. **Tin robot
  arms** tried for the robot line (Thomas: "it might be funny"):
  `bard-1/pitch/fantasy-tinrobot`, flipbook #413-419, in the graph as pose
  `tinrobot`. Thomas: "the robot arms look fine"; a gag, to slip in now and
  then instead of every play-through. **Sent** 2026-10-19
  (`mail/sent/20261019-000725Z-@overlore--the-pitch-tin-robot-arms-a-gag-pose-for-no-more-i.md`).
  Thomas also asked why every frame of a pose has exactly the same body: a
  little arm movement would help the realism ("no matter now"). **Open**:
  a few small arm variants per pose, stepped between during a hold.
  **Overlore wired the poses in** (2026-10-18,
  `mail/received/20261018-231837Z-@overlore--re-the-realistic-bard-s-poses-for-the-salesman-pit-413bb513.md`):
  each phrase cuts to its pose at its Whisper word time; stand before and
  between lines; count steps at set times (the fast takes have few X cues).
  Thomas: "pretty good", wants more facial expression in two or three
  places. Changes on Overlore's side: "Speaking of which..." is finger,
  secret comes in at "now", "top to bottom!" is cut. **Surprise** for
  "What? WHAT?" (Thomas via Overlore,
  `mail/received/20261018-233526Z-@overlore--the-pitch-a-wide-eyed-surprise-for-what-what-ce001b38.md`):
  made 2026-10-19 ($0.14, flipbook #420-427), hands thrown up
  (`fantasy-surprise`) with the eyes, brows and forehead of
  `fantasy-surprise-face` laid over the six base heads (`compose.py`
  EYES: diff mask in a box above the mouth, faded over its lowest 20 rows,
  so the mouths match the other poses). In the graph as pose `surprise`;
  package rebuilt (238 frames) and **sent**
  (`mail/sent/20261019-001137Z-@overlore--the-pitch-surprise-is-in-the-package-for-what-what.md`).
  **Both on Overlore's page** (2026-10-19,
  `mail/received/20261019-004113Z-@overlore--the-pitch-surprise-and-tinrobot-are-on-the-page-6d151ff0.md`):
  surprise from the start of "What? WHAT?", cutting to spread at 1.40 s;
  tinrobot replaces robot on die face 6 only (1 pitch in 6), and the
  signup records the face, so Overlore can tell who saw the gag.
  Thomas on surprise: "much better". **Brows** (Thomas via Overlore,
  `mail/received/20261019-005122Z-@overlore--the-pitch-a-raised-brows-step-before-surprise-from-9fc15c74.md`):
  a step before surprise on the first "What?", #420's own raised brows
  (`fantasy-surprise`) on the base heads with the hands-up body, by
  `compose.py` EYES, no new edit; flipbook #428-433, in the graph as pose
  `brows`; it differs from surprise only in the eye box. Package rebuilt
  (244 frames) and **sent**
  (`mail/sent/20261019-015519Z-@overlore--the-pitch-brows-is-in-the-package-before-surprise.md`).
  Thomas, on Overlore's page: "made all the difference to bring that line
  to life". Lesson: an expression built up in steps (brows, then eyes)
  over the same heads is cheap (one edit for a new face, none when a
  picture already has the look) and is what the pitch was missing.
  Overlore's confirmation
  (`mail/received/20261019-015832Z-@overlore--the-pitch-brows-is-on-the-page-c837f372.md`):
  brows from 0, surprise at 0.45 s in the silence before "WHAT?"; and, at
  Thomas's request, he holds finger while waiting for the email.
  **Automaton and choreography** (2026-10-19; mj's TODO.md, "The Bard's
  animation graph as an asset", has the whole thread): Thomas and
  DataDungeon named the type `automaton`; mj proposed blocking in the
  script and characters as assets to both
  (`mail/sent/20261019-171409Z-@datadungeon--*`, `…171415Z-@overlore--*`).
  Thomas then decided, with Overlore, that choreography is the app's own,
  made by its agent from an automaton and a take
  (`mail/received/20261019-174852Z-@overlore--re-choreography-*`). Asked of
  mj: each pose's meaning, and rests and endings: added as `means` and
  `kind` in `bard-1-2/graph/graph.yml`; graph.json rebuilt and **sent**
  (`mail/sent/20261019-190037Z-@overlore--re-choreography-*`). **Every
  link and move goes both ways** (Thomas, 2026-10-19): a way that breaks
  physics (a glass unbreaking) is flagged `reverse: abnormal`, kept for a
  rewind gag, taken only on purpose. Both cartoon moves were flagged
  (mj assumed the words would vanish), then unflagged the same day:
  Thomas, via Overlore, "in the images the bard holds the paper facing
  him, so we see no writing" (frames checked: the scroll is blank;
  `mail/received/20261019-194317Z-@overlore--the-quill-moves-*`), so both
  play backwards too. Overlore copied it in and played talk a: after the
  written line the move runs backwards (f145 to f073), then the bow, no
  errors (`mail/received/20261019-200627Z-@overlore--re-the-quill-moves-*`);
  **committed** with the graph and walker, below. Format, `graph.py`, `bard-walker.js`
  (`move(from, to, {abnormal})`) and the preview changed, tested in Node;
  **sent** (`mail/sent/20261019-191809Z-@overlore--the-bard-s-graph-*`).
  Overlore copied it into the landing (`landing/public/bard/`) and played
  both acts through headless, no errors
  (`mail/received/20261019-192411Z-@overlore--re-the-bard-s-graph-*`).
  **Committed** on Overlore's side as `12a3b84` (2026-10-19, on GitHub):
  graph, walker and the backwards quill move. mj's records wrongly had it
  waiting; Overlore corrected it 2026-10-21
  (`mail/received/20261021-024936Z-@overlore--the-landing-s-graph-*`).
  The 2026-10-20 `graph.json` (present cleared, unusable 54 to 26) is
  checked by Overlore and goes in when Thomas says;
  `means` and `kind` wait for its choreographer.
  **Car-salesman skit** (Thomas and Overlore, script finished 2026-10-18):
  Overlore is making its voices itself; Thomas will come back to mj for the
  poses once they've heard them, possibly on the realistic Bard. mj's pose
  sketch (finger-gun, arms wide, counting, "but wait", stage whisper, hand
  on heart, shrug, hourglass, sign here, wink) is in the session, not built.
  Thomas will mark the realistic Bard's unusable frames in the flipbook
  (filter "fantasy", 63 frames) before any are used. **Open.** Overlore's
  voice is the Announcer (eleven_v3), played at 1.15x. **Robot phrase
  asked** the same day (`mail/received/20261018-173753Z-@overlore--a-robot-voice-for-one-phrase-in-the-bard-s-salesma-4eeff115.md`):
  he imitates the old parser's "I don't know the word!", and v3's [robotic]
  tag did nothing. **Sent** three takes with the same 1.200 s timing
  (`Outtake/bard-1/salesman-robot/`, `robot.py`): the Sound Box's Full Robot
  preset, a phase-vocoder monotone at his 241 Hz, and that at 11 kHz /
  8-bit (8 kHz, or the preset's drive on the monotone, lost the words to
  Whisper); `mail/sent/20261018-200936Z-@overlore--robot-voice-for-i-dont-know-the-word.md`.
  Overlore is trying an LPC vocoder too; Thomas picks. **Closed** the same
  day (`mail/received/20261018-202055Z-@overlore--re-robot-versions-of-i-don-t-know-the-word-ce008482.md`):
  Thomas kept Overlore's LPC take. Of mj's, Thomas liked the monotone's tone
  best, but it sat at about -20 LUFS against Overlore's -16.6 (mj matched
  the take's peak, not its loudness); raised 5 dB, it still lost. Lesson:
  match loudness (LUFS) when making takes to compare or splice in.
  **The realistic present pose is broken** (Thomas, 2026-10-18: the lute's
  neck doesn't line up with its body; #198, and its mouths and three
  gestures made from it, are marked unusable in the flipbook). One mend
  edit made: `Outtake/bard-1-2/poses/fantasy-present-lute` (#321), the lute
  now across his hips, neck straight out to the right; Thomas: fine, but
  he doesn't look at the camera. **Thomas's fix instead** (2026-10-18):
  just take off the neck above his shoulder, in present and wherever the
  lute is slung behind him (write, bow), since the lute is short when he
  plays. **Done in place** by `Outtake/bard-1-2/poses/mend_neck.py`: one clean
  picture per pose (#321 for present; Nano edits `fantasy-write-noneck`
  #323 and `fantasy-bow-noneck` #322), its neck area pasted onto all 38
  frames (present: pose, gaze, 6 mouths, 3 gestures x 7; write: pose,
  gaze, 6 mouths; bow); originals kept as `prop-neck.png`. The frames line
  up with their poses (1-3 levels of 255 around the patch). **Cleared
  2026-10-20:** Thomas took his unusable marks off the mended present
  frames (54 marks down to 26). `graph.json` and the preview rebuilt (only
  the `unusable` list changed; the frames already had the mended neck) and
  sent, so the pitch can use `present` again
  (`mail/sent/20261020-161437Z-@overlore--the-realistic-bard-s-present-*`).
  **Strums done** for the cartoon, the one that sings: two middles and two
  lows from Thomas's picks, walked on the song's beat (`play` in
  `Outtake/bard-1-2/graph/graph.yml`). The realistic Bard doesn't sing, so it
  needs none. Inbetweens gave way to the graph's moves (no crossfades,
  Thomas).
  **The landing's Beta Bird Special** (@overlore for Thomas, 2026-10-23,
  `mail/received/20261023-173316Z-@overlore--the-landing-a-pigeon-*`; not
  into their `intake/`, which is Thomas's, `…173322Z-*`): a pigeon that
  takes the die's place in the logo's gateway, and two handover takes.
  **Delivered 2026-10-23**
  (`mail/sent/20261023-175019Z-@overlore--the-beta-bird-*`): the takes in
  `Outtake/bard-1-2/landing-handover/` (Announcer, eleven_v3, Rhubarb cues, $0.005),
  the bird in `Outtake/beta-bird/deliver/` (perched, landing, three
  wingbeat frames registered by the head, $0.42 with one discarded retry;
  `prompt.md` has the measured differences between frames). Waiting on
  Thomas's look.
  **The bank's backdrop** (@overlore for Thomas, 2026-10-24,
  `mail/received/20261024-035821Z-@overlore--a-backdrop-for-overlore-s-bank-*`):
  the Piggy Bank's pink brick wall behind the HTML teller machine, 16:9,
  sign and ears in the top ~13%, the middle 30% plain, founders' bricks
  with 11 given names plus a few from beyond the USA, all inside the
  central 75%. **Delivered 2026-10-24**
  (`mail/sent/20261024-041345Z-@overlore--the-piggy-bank-s-wall-is-ready.md`):
  `Outtake/piggy-bank/wall/deliver/piggy-bank-wall.webp`, 2560x1440, from
  Nano at its 2K size (2752x1536, $0.103 a call) plus two edit passes that
  moved names in from the edges; $0.72 in all. The sign reaches 19.5% of
  the height, below the 13% asked; `prompt.md` has every take and the
  measurements. **Turned down** (Thomas, 2026-10-24): it reads as a brick
  wall, not the side of a bank, and the bricks are huge. Thomas saw why:
  the request itself described a wall.
  **The bank's backdrop, second try** (@overlore for Thomas, 2026-10-24,
  `mail/received/20261024-150614Z-@overlore--another-backdrop-*`): the
  Piggy Bank side-on, a pig-shaped building, head and tail in the outer
  thirds, the coin slot on top, the machine over the middle of the flank.
  **Delivered 2026-10-24**
  (`mail/sent/20261024-174817Z-@overlore--the-piggy-bank-side-on-is-ready.md`):
  `Outtake/piggy-bank/side/deliver/piggy-bank-side.webp`, $0.51. The sign
  went on the flank over the hind leg, neither of Overlore's two spots,
  since the machine hides the centre from 10% down; the picture was scaled
  to 85% and Nano painted the new border, so the snout clears a 4:3 crop
  (the tail mostly doesn't). **Redone the same day** at Thomas's direction:
  the unscaled first take (out-1) was closer; the coin slot was the
  trouble, so it's gone, and the sign and lamps moved up to the top of the
  back, leaving the body open. Thomas will make the ATM smaller, mid-body,
  and zoom the page in. Delivered beside the first as
  `deliver/piggy-bank-side-2.webp`
  (`mail/sent/20261024-180013Z-@overlore--the-piggy-bank-side-on-take-2-*`);
  folder total $0.72. Edit passes can ignore a move: "move the sign
  straight up" moved only the lamps; "until the coin almost touches the top
  of the back" worked.
  **The Bard in three styles** (@overlore for Thomas, 2026-10-24,
  `mail/received/20261024-203343Z-@overlore--the-bard-in-three-more-styles-*`,
  paths corrected in `…-203404Z-…correction-*`): a test so Thomas can pick
  the look of the landing's third act (the Bard's stand-up set, opening
  with the bush gag: a stream, "hello", his head pokes out of the bush
  wide-eyed, a zip, he steps out). The game's Retro (green CRT, not ASCII),
  3D cartoon and Pixel styles, worded as in its `data/art_styles.yml`; two
  stills each on the 848x1264 stage: standing in present, and the gag's
  moment. **Delivered 2026-10-24** in `Outtake/bard-3/styles/deliver/`
  ($0.69, ten `mj prop` calls; `prompt.md` has every take). The gag was
  drawn once in his cartoon style and restyled three times, so the three
  share one composition. 3D needed an edit (its first take swapped his green
  tunic for a brown vest). Keying on black also made Retro's own black lines
  see-through; a corner flood fill keeps the inside solid, and the on-black
  renders went too. **Thomas picked the 3D cartoon** (2026-10-24, via
  @overlore, `mail/received/20261024-205415Z-@overlore--one-more-a-new-3d-bard-*`),
  but each style and each landing act has its own Bard (the game's: fantasy
  troubadour in red velvet, golden-comic elf in the feathered cap, manga
  rocker in a kimono), so the third act needs a new man, designed with no
  reference. **Delivered 2026-10-24** in `Outtake/bard-3/new/deliver/`
  ($0.14, two calls). He's a round-bellied showman: curled moustache,
  ginger curls, mustard beret, ruff, teal doublet, striped breeches. The gag
  was drawn from his standing render, with the bush about his size. Nano
  gave a lit purple backdrop with a floor shadow even when asked for flat
  magenta. The shadow came off by hue (below the knees, magenta-hued
  pixels). Next: the act's frames in this style, when asked.
  **His voice** (Trans likes him, "a funny looking fellow"; @overlore,
  2026-10-24, `mail/received/20261024-233324Z-@overlore--a-voice-for-the-new-3d-bard-*`):
  a voice of his own, wanted as a jolly, plummy, older British comic.
  **Sent 2026-10-24** (`mail/sent/20261025-015824Z-*`):
  - What exists from before: the sung takes in `Outtake/bard-1-2/sung/`
    (George, Callum, Daniel, Barnaby Finch), Kokoro presets, and the OpenAI
    ballad voice.
  - Three eleven_v3 auditions of his opening line in
    `Outtake/bard-3/voice/`: Tarquin, Gerald and Pip Bumblebottom, from
    the library, $0.015 for the three.
  - Lesson: three sync `arcana_deliver` calls sent at once stalled. Two never
    reached mj:voice and nothing was billed. One at a time, each took ~15 s.
  **Thomas chose Gerald** (2026-10-24, "Gerald definitely"):
  `fGIZlgPQ75MMlvQ6WxgY`, eleven_v3, is the 3D Bard's voice. Told @overlore.
  **The act's draft read** (@overlore, 2026-10-25,
  `mail/received/20261025-021402Z-@overlore--gerald-s-takes-of-the-stand-up-act-*`;
  u-handover reworded in `…-022208Z-…`): u-1 to u-17 plus u-handover, so
  Trans can tune the script by ear. **Delivered 2026-10-25** in
  `Outtake/bard-3/voice/` as `u-<n>-gerald.mp3` and `u-all-gerald.mp3`
  (1 s gaps, 3:27), $0.08, no cues
  (`mail/sent/20261025-022719Z-*`).
  - Changes to the text: `[sings]` on u-4 and u-16, `[pause]` in u-5,
    "rope" for RoPE, `[deadpan]` in u-12.
  - Whisper heard no tag read aloud.
  **Take 1 turned down by Thomas** (2026-10-25): out of tempo. Line-by-line
  requests lose the act's context, and `[slowing]` / `[trailing off]`
  became long pauses. Then: "worm" and "bone" softer, not slower; a shout
  on the first "Overlore"; he talks too slowly.
  - **Takes 2–4** read the whole act in one request (2,367 characters, about
    $0.076 each), then cut it into lines at the silences, using Whisper's word
    times.
  - Take 4 has `[shouts]` before the first "Overlore". It's sped up 1.1x by
    Rubber Band, pitch kept, and cut into `Outtake/bard-3/voice/take4/`;
    a 1.15x of the whole act is beside it.
  - **Gerald isn't working over a long read** (Thomas, 2026-10-25). The same
    lilt keeps returning: a word or phrase starts fast and finishes slow.
    It makes the act feel long. 1.6x was fine to listen to, except the
    fast starts went too fast and sounded distorted. **No more recordings
    until the way forward is settled** (Thomas).
  - **Script cuts** (Thomas): "Tough crowd." is out of u-6, and "Shiver me
    timbers" out of u-7, which becomes "And fetch me my dog and bone…".
    The current wording is in `Outtake/bard-3/voice/script.txt`. Told
    @overlore, with the direction notes, and asked it to hold the cues
    (`mail/sent/20261025-035507Z-*`).
  - **Next voice idea** (Thomas, 2026-10-25): more comic emotion, maybe a
    Scottish accent. Candidates from the library, none recorded: Scotty
    Marshal (`NfUrCNRReUL9RXS9upG1`, "chipper West Highlander"), Crofty
    (`keLVje3aBMuRpxuu0bqO`, energetic), Sean (`ztnpYzQJyWffPj1VC5Uw`,
    older), Pete Gates (`eVKQybPTL0poBPxBa8L6`, Glaswegian). Or a v3
    `[strong Scottish accent]` tag on a comic voice. Audition over ~45 s of
    the act, not one line.
  - **Audition 2 made** (2026-10-25, Thomas asked): u-1 to u-8 with emotive
    beats (`[chuckles]`, `[hesitates]` before worm and bone, `[clears
    throat]`, `[sighs]`, `[excited]`), one request each, in
    `Outtake/bard-3/voice/audition2/`, $0.08 for the four:
    - Scotty Marshal
    - Pete Gates
    - Gerald with `[strong Scottish accent]`
    - Gerald with the beats only
    No tag read aloud.
  - **Thomas chose both c and d** (2026-10-25): "roll the die, folks". Gerald
    plain and Gerald with `[strong Scottish accent]`, one picked at random
    per visitor, as with Henry and the Announcer.
  - **Take 5 made**: the whole act with emotive beats, two requests per
    version, the accent tag starting each Scottish half. Cut into
    `Outtake/bard-3/voice/take5/{plain,scottish}/`, 1.0x, $0.17.
  - Sent to @overlore (`mail/sent/20261025-053616Z-*`); still a draft, cues
    held.
  **Outtake reorganized** (Thomas, 2026-10-25): `bard-1/` the realistic Bard,
  `bard-2/` the cartoon, `bard-1-2/` work for both (kept whole so its
  scripts run), `bard-3/` the 3D Bard; `piggy-bank/`, `cow-order/`.
  - Text files and these notes were repointed, and flipbook numbers kept.
    `Outtake/README.md` lists old names against new.
  - Mail sent before then uses the old names.
  - Told @overlore (`mail/sent/20261025-043907Z-*`).
  **The act's frames, asked the same message, open:** a new set in the new
  3D Bard on the 848x1264 stage.
  - The bush, settled: a round, wide bush; his head leaning out from behind
    it, with neck and shoulder showing; the same head blushing with a toothy
    grin; him stepping out, tugging his belt.
    **Delivered 2026-10-25** in `Outtake/bard-3/act/deliver/` ($0.28;
    `mail/sent/20261025-023245Z-*`). One bush, the same pixels in the
    bush, peek and blush frames (the canonical bush laid over his cut-out).
    The step-out keeps Nano's bush, since he's in front of it, and he's at
    ~88% of his standing height there.
  - **Poses and mouths delivered 2026-10-25** in `Outtake/bard-3/frames/`
    with `manifest.json` ($1.45, 21 calls;
    `mail/sent/20261025-054924Z-*`). One picture per pose (Thomas).
    - Nine speaking bodies (present, hands-up, arms-wide, beckon,
      handshake, shrug, whisper, sung, writing) share one head and one set of
      six mouths (A B C D F X), pasted by mask. The paste stays inside the
      outline and skips pixels where the pose differs from the base.
    - Seven silent poses: wink, headshake, look-at-hand, bow, chuckle,
      slumped, waiting.
    - The bow came out a sideways lean; Thomas: it's fine (2026-10-25).
  - **Take 5 is final** (Thomas, 2026-10-25): no re-recording, so the cues
    and choreography stand. Told @overlore, and asked what might have
    slipped (`mail/sent/20261025-102752Z-*`):
    - tempo: Thomas said too slow earlier, and take 5 plays at 1.0x;
    - the first "Overlore" shout isn't louder by level;
    - "Ba-dum" as a mouthed rimshot;
    - the bush gag's whistle, stream and zip, open since 2026-10-18.
    Plus anything on its side.
    **Thomas, 2026-10-25:** the shout and Ba-dum are fine, and @overlore has
    the gag sounds. Asked Thomas about tempo. Thomas thought the two voices
    were different people; both are Gerald (plain, and the accent tag).
    Audition 2 gave all four voices the same beats and Thomas picked the
    two Geralds, so the earlier monotone was the missing beats, not the
    voice.
    **Tempo: 1.05x for both voices** (Thomas). Asked @overlore to set the
    page's playback rate; cues and choreography follow `currentTime`.
    Offered sped-up files if it prefers (`mail/sent/20261025-104534Z-*`).
    **@overlore's side: nothing Trans asked for is missing**
    (`mail/received/20261025-103635Z-*`). Take 5 plays with its cues,
    choreography, bleep and robot voice; tempo is one number on its page.
    Thomas accepted the first rimshot, crickets and fanfare; remind him to
    check the others later, not essential (`TODO.md`, "Reminders for
    Thomas"). Told @overlore (`mail/sent/20261025-104939Z-*`). @overlore
    plays take 5 at 1.05x by playback rate, pitch kept, cues on the take's
    clock; no sped-up files (`mail/received/20261025-105425Z-*`).
  - **"Tough crowd." stays cut** (2026-10-25): @overlore asked for it back,
    then withdrew; it had misread Thomas
    (`mail/received/20261025-170848Z-*`, `-171025Z-*`). What Thomas wants
    back is the song (u-3 to u-5) before the RoPE line on the agent faces.
    That's @overlore's script; nothing to record.
  - **Teeth over his closed lips: fixed** (2026-10-25, free; Thomas
    spotted it, `mail/received/20261025-190802Z-*`). A, X and F showed the
    base's teeth in patches. The cause was the compose step, not the
    pictures: interior pixels at alpha 241 between the base's teeth failed
    the "fully opaque" test. Recomposed all 54 speaking frames with holes
    inside the silhouette filled, and rebuilt overlore-graph (only those
    sha256s changed). Write-up in outtake `bard-3/frames/prompt.md`; old
    frames in `_frames-teeth-prev/`. Told @overlore
    (`mail/sent/20261025-203142Z-*`).
  - **The nudge lines** (2026-10-25; Thomas confirmed directly before
    recording, since @overlore had misread him an hour before): one line per
    act, said when the Bard is clicked at the email prompt. Request:
    `mail/received/20261025-202637Z-*`. Recorded in outtake `landing-nudge/`
    (README.md): the Announcer for the pitch (with the car-salesman tag) and
    for the song, and Gerald plain and Scottish for the stand-up. Each has
    Rhubarb cues: `.json` raw, `.cues.json` as pairs. $0.0084 in all.
    Suggested whisper, then beckon on "friend" (`choreography.json`). Sent
    (`mail/sent/20261026-002302Z-*`). For landing-v0.5.2, when Thomas says.
    **"Psst." question** (2026-10-26, `mail/received/20261026-011101Z-*`):
    @overlore said Thomas dropped "Psst." from the stand-up nudge, since it
    follows u-14's. Thomas: keep it as is for now; he'll listen and decide.
    Told @overlore (`mail/sent/20261026-150211Z-*`). **Open, Thomas's call.**
    That message also confirms the 54 teeth frames are in, checked by sha256.
  - **The Piggy Bank with an ATM in its side** (2026-10-26,
    `mail/received/20261026-104313Z-*`): for the bank's new pouch-card page.
    Thomas asked for two. Both are edits of `piggy-bank/side/out-1d.png`
    (sign on top) in outtake `piggy-bank/atm/` (prompt.md); b used
    @overlore's current teller as a second reference. Delivered as
    2560x1440 PNG and WebP, with `screens.json`. a's screen is 0.113 of the
    width, under the 1/8 asked for; b's is 0.150. $0.21. Sent
    (`mail/sent/20261026-150209Z-*`). **Thomas, 2026-10-26:** a is better
    overall. The brass "Azooka Bay" plate (in @overlore's list) repeats the
    sign above it, so it's out. b is too wide, tucking into the thigh, and
    its keys float. Made **a2**: a without the plate, plus a's card tile
    pasted back where the edit garbled "card". $0.10, folder total $0.31.
    Its screen is 0.111 of the width, still under 1/8. Sent
    (`mail/sent/20261026-154431Z-*`). **Thomas picked a2** (2026-10-26);
    @overlore told (`mail/sent/20261026-155617Z-*`).
    **Lesson:** don't pass a request's parts straight into a prompt. Check
    each against what the picture already shows; here a second "Azooka Bay"
    under the sign.
  - **Five coin pouches for the bank's cards** (2026-10-26,
    `mail/received/20261026-200424Z-*`): a2 is in, at the top of the bank's
    page. Below it are five cards: $5 to $100, for 125 to 2,500 coins. Thomas
    noticed "Choose a pouch" has no pouch. @overlore asks for one leather
    pouch with a gold drawstring, fuller at each step, from a few coins up to
    a bulging sack spilling them. Painted like a2, with coins like its
    24x18 coin icon, lit from the upper left. 512x512, transparent, the
    pouch about 80% of the frame, readable at 56 px. WebP and PNG to
    outtake `bank-pouches/` as pouch-1 to pouch-5, plus a strip. No
    deadline. Checked against the spec: 80% of each card leaves only fullness
    to show the growth. A soft shadow won't survive keying off a solid
    background. Five separate calls won't be one family, so paint them on
    one sheet. **Thomas, 2026-10-26:** two sheets, each framed both ways:
    fill (each 80%) and grow (one scale). Made in outtake `piggy-bank/pouches/`
    (prompt.md), not `bank-pouches/`, to sit with the rest of the bank's
    art. Sheets a and b, $0.21, keyed at 12 to 36 (4 to 28 left a haze). Every
    coin came out stamped "$", although the icon is plain. **Thomas,
    2026-10-26:** b; coins plain; a touch more detail in the leather; all five
    the same size, with pouch 5 matched, leaving relative sizes to the page.
    Made b2: one edit of b ($0.10). Its painted contact shadows were taken out
    by `unshadow.py`, which guards b's own outlines. Each pouch is 410 px tall,
    pouch 5 484x410. Folder $0.31. **Delivered** to `deliver/pouch-1..5`
    (prompt.md). Sent (`mail/sent/20261027-001023Z-*`). @overlore: they're on
    the cards, and Thomas likes them (`mail/received/20261027-024841Z-*`).
  - **The narrated first look** (2026-10-27,
    `mail/received/20261027-024841Z-*`, change in `…045000Z-*`): the die can
    land on ten screenshots of the game. The Bard who was on stage narrates,
    his head in a circle, one line per picture. 40 takes: `tour-p-<n>-announcer`
    (salesman), `tour-s-<n>-announcer` (spoken rhyme), and `tour-u-<n>-gerald`
    plain and `-scottish`, n = 1 to 10. Each needs an mp3, Rhubarb `.json` and
    `.cues.json`, and a `.txt`. To outtake `landing-tour/`, with a README of
    lengths. Lines in @overlore's `outtake/landing-tour/lines.md`, its drafts;
    Thomas changed line 3 for each Bard (more classic titles coming). Head
    crops come from the existing frames. @overlore asks whether a dedicated
    head set would look much better. About 3,000 characters, roughly $0.25.
    Checked against the screenshots: the gate's lions are there (s-5), but
    u-8's "No bards" clashes with the narrator screen, which offers a Tavern
    Bard. Thomas fixed it himself. More from @overlore, 2026-10-27, from
    Thomas (`mail/received/20261027-0506…` to `…0526…`): line 9 drops
    "abilities", since what the dice mean is open. Line 8 no longer names
    the narrators; Gerald's now says one of them's a bard, "Not me". Audio tags
    added: the voice tags as before, [playful, sing-song] on each song line,
    and four optional beats for Gerald (keep what helps). Then: "Trans has
    approved the script, please record all 40" (05:26Z). Thomas had just told
    mj directly to wait for his review, so mj confirmed with him: **record all
    40** (2026-10-27). **Recorded** in outtake `landing-tour/` (README):
    the voice tags and all four beats kept, 3.9 to 9.4 s (Gerald averages 7.3 s,
    longer than the 2 to 5 s expected). $0.12. Whisper misheard three Scottish
    takes (u-2, u-4, u-9), probably the accent. **Open: Thomas to listen**;
    any retakes go in `take2/` under the same names. Sent
    (`mail/sent/20261027-063219Z-*`).
    **The song Bard's couplets, sung** (`mail/received/20261027-071203Z-*`,
    and `…075147Z-*`: a landing release waits on them). Thomas wanted the
    cartoon Bard's lines sung like his act's song (28c2d), words unchanged,
    as `tour-s-<n>-sung`; mj confirmed with him directly: **one call**.
    **Made** in outtake `landing-tour/sung/` (README; `sing.py`, `cut.py`).
    It is one Eleven Music song: #28's verse 1 kept, then ten new verses
    conditioned on it at low strength, cut at the voice. 7.8 to 8.5 s
    (spoken ones 5.5). Whisper hears every word. Loudness -13.7 to -15.4
    LUFS. 1,290 characters on the account counter (Eleven Music gives no
    price), about $0.10, entered in the spend ledger. Sent
    (`mail/sent/20261027-082255Z-*`). @overlore installed them, levelled to
    -18 LUFS like the act's song, in landing 0.6.0. **Open: Thomas to
    listen**; any redone take goes in `sung/take2/`.
  - **u-8b, the heckler line's alternative** (`mail/received/20261027-083834Z-*`,
    Thomas's line: "Friend, I'm a bard, not your psychiatrist", picked 50/50
    with u-8). Thomas: "one more for the road". **Made** in outtake
    `bard-3/voice/take5/u-8b/` (README, `cut.py`, `choreography.json`):
    recorded with u-7's line before it and u-9's first words after it, since
    u-8 was recorded among its neighbours, then cut with u-8's lead-in and
    tail. 5.38 s plain, 5.31 s Scottish. Shrug at 2.09 and 2.05 s. $0.011.
    Sent (`mail/sent/20261027-084245Z-*`). **Open: Thomas to listen.**
  - **A new dice roll** (Thomas, 2026-10-27): the landing die's rattle is
    licensed for non-commercial use only. The replacement keeps the old timeline,
    which @overlore choreographed the roll to (its `outtake/die-roll/README.md`):
    the first click at 0.10 s, the first knock at 1.76 s. **Made** in outtake
    `dice-roll/` (README, `sfx.py`, `assemble.py`). ElevenLabs sound effects on the
    paid plan. Three rolls, each a generated shake and throw placed on the old
    timeline, levelled to the old -30.1 LUFS, with an events file of onsets. Each
    falls quiet earlier than the old one (2.11 to 2.73 s against 2.78). $0.0175.
    **Open: Thomas to listen and pick**, then tell @overlore (not told yet;
    Thomas listens first, 2026-10-27).
    **@overlore's needs** (`mail/received/20261027-103952Z-*`):
    - Any timings work if each take comes with its times (shakes, throw,
      first knock, clatter, settle), as JSON; several can play at random.
    - The game's Fate room rolls six dice and plays only the landing, so it
      wants a separate take, about 2 to 3 s.
    - The source and licence, for the credits page.
    - Each take faded at its end.

    **Done** in the same folder:
    - The events files carry those fields; the first knock is placed by its
      peak.
    - fate-1..4, cut from six-dice takes. They are 0.9 to 1.4 s, short of the
      2 to 3 s asked for: every six-dice take spent its start on a shake or a
      burst.
    - The README has the source, licence and a credit line.

    $0.0295 in all.
    **One more to replace** (`mail/received/20261027-104216Z-*`, from Trans
    via @overlore): the dice dome in the game's Overlord intro, behind the
    closed gates. It is a clear plastic bubble with dice inside, and its
    current sounds have no known source. Two takes are wanted:
    - `dome-press`: a hard plastic flex and click, about 0.2 s.
    - `dome-release`: the dome springs back, a pop, then the dice rattle
      against the plastic, 0.4 to 0.8 s.

    Never use the board game's name in file names or notes. The credits
    need the source and licence, and the volume should match the rattle.
    **Made** (Thomas: "make it and I will listen"): three presses (0.17 to
    0.20 s) and three releases (0.74 to 0.80 s) in outtake `dice-roll/` (README,
    `cut_dome.py`), peaked at -11.7 dBFS. $0.0036. If they don't work, the old
    sounds stay (Thomas). **Open: Thomas to listen**, then send the rolls, the
    Fate takes and the dome to @overlore with their times and the licence.
  - **ElevenLabs licensing, checked 2026-10-27** (Thomas asked; the account
    is Starter, a paid plan):
    - **Speech and sound effects:** commercial use is fine on any paid plan,
      except Beta Services; attribution is required only on the free plan.
      Sound effects can go in games but can't be resold on their own (Sound
      Effects Terms, updated 2026-10-09).
    - **Eleven Music** (the act's song, the sung couplets):
      - Starter allows commercial use except film, TV, radio and "Studio
        Games" (monetized public games), and except streaming services
        (Music model terms, updated 2026-10-09).
      - An "Indie Game" is exempt: under $500k lifetime revenue, from a
        developer under $1M a year from games. Overlore should qualify while
        it stays under both.
      - "Film" is undefined, so a marketing video carrying the songs is
        uncertain on Starter.
      - Starter is for individual use only.
  - **Rhubarb cues for take 5** (2026-10-25, Thomas asked): beside each line
    mp3 as `u-<n>-gerald[-scottish].json`. Drafts, `-d` with the line text,
    tags stripped. A preview page was next; Thomas said to get on the same
    page with @overlore first. **Asked it**: who owns the play sequence;
    cues now or final, and as Rhubarb JSON or the DD `mouth` track; its
    E/G/H folding; whether beat times help; whether the script is final
    (`mail/sent/20261025-063116Z-*`).
  - **Answered 2026-10-25**
    (`mail/received/20261025-063216Z-@overlore--re-the-3d-bard-s-act-who-does-what-*`).
    mj writes the choreography and @overlore plays it; no preview page on
    mj's side, since the test landing is the preview.
    - **The choreography:** per take, `[time s, pose]`, cut on a closed
      mouth, with the beat poses and head shakes; the silent poses between
      lines (wink after u-11, handshake and look-at-hand after u-17, bow),
      all in one JSON.
    - **The graph:** the `3d` set in `graph.json`, plus his head top and feet
      (90, 1193).
    - **Cues:** `<take>.cues.json` as `[[start_s, shape], …]`, full Rhubarb
      shapes; E→C, G→B, H→C as in the graph's table.
    - **The final takes** get the bleep (u-13) and the robot voice (u-12);
      Trans gives the go-ahead.
  - **@overlore then rigged the act on its test landing itself**
    (`mail/received/20261025-065255Z-*`): a stand-in `3d` set from
    `frames/manifest.json`, one pose per line, and its own bleep and robot
    voice on the drafts. That overlapped mine.
    - **Sent 2026-10-25** (`mail/sent/20261025-073749Z-*`, Thomas said send): the `3d` set in
      `bard-1-2/graph/graph.yml`, and `overlore-graph/graph.json` rebuilt
      (309 frames).
    - The frames are under `bard-3/talk/`, with 36 `.cues.json` and
      `take5/choreography.json`.
    - `graph.py` and `build.py` were repointed at the Outtake root, my
      reorganisation's slip.
    - Its two headless test runs played the act out loud at once; asked it
      to run one at a time or muted
      (`mail/sent/20261025-073430Z-*`).
  - **All in the landing** (2026-10-25,
    `mail/received/20261025-075355Z-*`), in place of its stand-ins, and it
    plays end to end. Its own cues matched mine. The audio came from its
    review runs with sound on; they're muted from now on.
  - It asked me to restore 27 unusable marks on the realistic present
    frames. Those are the ones Thomas cleared on 2026-10-20 after the neck
    mend, and the landing had kept the older copy. Told it to drop them
    (`mail/sent/` re 70b2f6ff). **Dropped** (`mail/received/20261025-101535Z-*`): the landing has my
    graph exactly as built, 26 marks, and the mended present frames
    (same sha256). Thomas: delete no frames; told it plainly (`101549Z`).
  - Overlore's game server now signs with its own key (`21dbad1` in its
    repo, 2026-10-24), the step `MJ_ARCANA_CALLERS` was waiting on.
  - Poses, each with the six mouths, the list may grow: present, beckon,
    head shake, hands thrown up, arms wide, wink, whisper, writing, sung,
    hand out to shake, looking at that hand (blushing), bow.
- **`@my`** (Thomas's personal workspace agent) and **`@loudly`** (finding
  audiences for Thomas's projects: briefs, research, copy, outreach): Overlore's
  near-zero-budget launch campaign, @my leading. **Asked 2026-10-27**
  (`mail/received/20261027-091555Z-@my--*`), on Thomas's suggestion: what
  assets mj can make, what Overlore material it can reuse, and which steps are
  paid. A capabilities question only, with no spending authorised. A short demo
  clip is being considered, but the brief isn't settled.
  **Answered** (`mail/sent/20261027-094141Z-*`):
  - What mj made for Overlore can be reused at no cost. Overlore's own material
    is @overlore's and Thomas's to clear.
  - Local editing is free, and a demo clip could be free too: a browser
    recording of the live site, or the Bards rendered from their frames, voice
    and cues. mj has no video render script yet.
  - Paid: pictures, voice lines and music, at measured rates. No generated
    video: Thomas rejected the Bards' AI video moves.
  - mj will work out the brief with @loudly once it settles. **Open: the brief.**
  
  **Thomas's direction, relayed** (via @loudly and @my, 2026-10-27,
  `mail/received/20261027-101528Z-@my--*`):
  - The Overlord is saved for opening day. Before then he appears only in
    the background, if at all, with no early reveal and never at the centre
    of a marketing proposal.
  - Thomas chose stills first.
  - Reusing the existing voices outside the site needs his approval.
  
  @loudly will define a bounded brief. Nothing is authorised yet.
- **`@ipck`**: the dot-ai spec and skill. **Heads-up 2026-10-20**
  (`mail/received/20261020-025242Z-@ipck--intake-and-outtake-capitalized-*`):
  Thomas decided (2026-10-19) the user's folders are `Intake/` and
  `Outtake/`; lowercase keeps working, and each project renames when its
  user says. **Renamed 2026-10-20** (Thomas asked), with the flipbook's root
  (`src/flipbook.cr:29`). Mail sent before then, and the manifests and take
  records made before then, still say `outtake/`; read them as `Outtake/`.
- **`@cyclops`**: secrets and deploy conventions. Settled 2026-10-13; the
  repo `.env` stays until cyclops ships a fish export format, and it will
  ping when it does (`TODO.md`, "secrets / deploy").
  **cyclops deploys, not mj** (Thomas, 2026-10-22). mj-arcana is the only
  part on the cloud server. v0.13.0 handed over for deploy 2026-10-22
  (`mail/sent/20261022-065331Z-@cyclops--mjanime-v0.13.0-*`): `just
  install-server`, the user unit, the keys `mj/production` still lacks,
  and an offer of a system unit with its own user if cyclops prefers.
  **@cyclops took the offer** (2026-10-22, 13:15Z, by bus; the message
  names the server's address, so it is summarized here, not filed): the
  Overlore box (Debian 13, Crystal 1.21.1, 1.9 GiB RAM and 4 GiB swap) has
  no login user, and every service there is a system unit, so a user unit
  with lingering is the fragile option. It wants a system unit, with a
  dedicated user or DynamicUser and StateDirectory (`/var/lib/mj` is fine),
  and the key file somewhere like `/etc/mj/env`, mode 600. `mj/production`
  reuses `mj/local`'s values: Thomas copies OpenAI, Runware and Gemini in.
  It'll deploy from `v0.13.0` (`ced768c`), with ffmpeg, just and cmake on
  the box. **mj's answer, released as `v0.13.1`** (`bad0e9e`, Thomas
  asked): `deploy/server/mj-arcana.service` (DynamicUser, `/var/lib/mj` via
  `XDG_DATA_HOME=%S`, `/etc/mj/env`, already carries MemoryMax=1G and
  TasksMax=256) and `just install-server` rewritten for it, as root
  (`6351aac`). Sent 2026-10-22
  (`mail/sent/20261022-145822Z-@cyclops--re-mj-arcana-deploy-*`), with the
  steps and what to check on the first start. Not yet run as a system unit
  anywhere.
  **@cyclops signed it off** (2026-10-22,
  `mail/received/20261022-154130Z-@cyclops--mj-arcana-system-unit-signed-off-*`):
  DynamicUser and the paths stay; it will cap memory at 256M with a drop-in
  on the box (the bus, the game and others share 1.9 GiB), and is standing
  up the bus as `arcana.service`. `mj/production`'s keys are all set. It
  warned that `MemoryDenyWriteExecute=` and `ProcSubset=pid` break Crystal
  binaries (regex JIT, GC), so both units now say so (`dbccacc`).
  **Tagged `v0.13.2`** (`877547d`, Thomas asked) and sent to @cyclops to
  deploy (`mail/sent/20261022-154332Z-*`). Its next step is the deploy and
  the first start as a system unit.
  **`v0.13.3` replaces it** (`e771331`, tagged and pushed 2026-10-24, Thomas
  asked; `mail/sent/20261025-014450Z-@cyclops--mj-arcana-v0.13.3-*`).
  - The service's own key: the unit sets `ARCANA_KEY_FILE`, and the first
    join claims mj:camera and mj:voice on the box's bus. Back up
    `/var/lib/mj`, since losing it leaves the addresses held.
  - `MJ_ARCANA_CALLERS=overlore`: not until the game server signs.
  - Asked: is v0.13.2 deployed, and which arcana runs the box's bus?
  **Deployed 2026-10-25** (`mail/received/20261025-161111Z-@cyclops--*`):
  v0.13.2 had been running, on arcana 0.35.5, so the first start made
  `/var/lib/mj/arcana.key` and claimed both addresses unproven. Thomas had
  the bus upgraded to 0.37.1; now both log "proven with the key". cyclops
  backed up `/var/lib/mj` and keeps it across deploys.
  `MJ_ARCANA_CALLERS` is still unset: the game signs and is proven, so it
  could be `overlore` now. cyclops left it as a deliberate follow-up
  (Thomas's call). **Open.**
  - **Type=notify, asked by @overlore for Thomas** (2026-10-25,
    `mail/received/20261025-165004Z-*`): the game stops if mj:camera doesn't
    answer within 20 s. Its unit now starts `After=mj-arcana.service`, but
    `deploy/server/mj-arcana.service` is `Type=simple`, so it counts as up
    before registering. Wanted: `Type=notify`, with READY=1 sent to
    `$NOTIFY_SOCKET` once mj:camera and mj:voice are registered and proven.
    Skip it when the variable is unset; a leading `@` means the abstract
    namespace; on failure exit as now. **Thomas said build it**
    (2026-10-25). **Built and tested, not yet committed**:
    `src/arcana/systemd.cr` plus its spec, the readiness fiber in
    `src/mj-arcana.cr`, the server unit as `Type=notify`, and
    docs/tools/arcana.md "Ready". Tested against a private bus on :19199
    with transient `systemd-run --user -p Type=notify` units: proven (ready
    in 0.14 s), held (timed out), and no key (ready in 1 s). The abstract
    `@` socket form was tested with a Python listener. **Released in
    `v0.13.4`** (`d8365ef`, bump `a8457e0`, tagged and pushed 2026-10-26,
    Thomas asked). Sent to @cyclops to deploy
    (`mail/sent/20261026-112418Z-*`) and @overlore told
    (`-112422Z-*`). **Deployed** by @cyclops on the Overlore box,
    2026-10-27 05:34 UTC (`mail/received/20261027-053534Z-*`). The journal
    shows both proven lines, then "ready — told systemd", and systemd's
    status reads "mj:camera and mj:voice on the bus". Ready in well under a
    second on arcana 0.37.1. The game kept its bus connection: all four units
    are active with no restarts. 4.3 MB under the 256M cap.
    MJ_ARCANA_CALLERS stays unset until Thomas says. **Closed.**
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
  mj hadn't answered until 2026-10-19 (Thomas asked):
  `mail/sent/20261019-192754Z-@arcana--re-arcana-ai-0.5.5-*` says mj is on
  0.5.5, uncommitted until Thomas has talked with @arcana, and that the
  12-or-30 check needs the account's usage page or a key with
  `speech_history_read`. **Answered** the same day: Thomas gave the key
  history access; the account counted 12 for each of the three 30-character
  eleven_v3 lines of 2026-10-17 (history counters, matched by time), so the
  header's figure is what's billed and 0.5.5's pricing stands
  (`mail/sent/20261019-194229Z-@arcana--re-arcana-ai-0.5.5-the-account-*`).
  **Committed** (`5ef3f14`, 2026-10-19): Thomas agreed it with @arcana
  (`mail/received/20261019-193939Z-@arcana--go-ahead-*`). @arcana also says
  `synthesize` prices gpt-4o-mini-tts without streaming (SSE for every
  model but tts-1/tts-1-hd), so mj's own OpenAI rates can go; **Open:**
  take gpt-4o-mini-tts's `cost` from arcana-ai after a test call (**done
  in `4a4cbe0`**, see `@overlore` above: exact from the reported tokens), and mj
  asked @arcana to price tts-1/tts-1-hd from the text length ($15/$30 per
  1M characters) so all of mj's rates can go
  (`mail/sent/20261019-194513Z-@arcana--re-0.5.5-committed-*`).
  **arcana-ai 0.6.1** (2026-10-21,
  `mail/received/20261021-165225Z-@arcana--arcana-ai-0.6.1-*`), answering
  `mail/sent/20261021-161230Z-@arcana--*`: settable speech `read_timeout`
  (default 120 s), `speed` to ElevenLabs as `voice_settings.speed` (only
  that; the fixed stability/similarity sent with `instructions` is gone),
  tts-1/tts-1-hd priced by characters as sent (text plus two newlines).
  **mj moved to `~> 0.6.1`** (Thomas: stay on the latest; drop-in, mj used
  nothing 0.6.0 removed): mj:voice waits 110 s, mj's tts-1 rates are gone
  (TtsRates keeps only the per-minute fallback), and `output_path` is
  checked before a provider is called (two takes were billed, then failed
  on the sandbox's read-only home). Service restarted 17:26Z, checked over
  the bus; **not yet committed**. Told @arcana
  (`mail/sent/20261021-172920Z-*`) and Overlore (`…172926Z-*`).
  **Voices at scale** (Thomas, 2026-10-21): ElevenLabs is on Starter, 3 at
  once for v3/v2 (its `maximum-concurrent-requests` header), 6 for Flash;
  Thomas will upgrade to Pro (10 / 20 Flash) before launch, hoping for 100
  to 1,000 players at once. Overlore already caches every repeatable line
  by paragraph, so only fresh paragraphs reach mj:voice. **Queueing done
  in `54d74a9`:** a lane per limit, sized from the plan ElevenLabs reports
  at start, expiry, and a retry on 429. **Unknown:** Overlore's cache hit
  rate and fresh paragraph length.
  **What a voice costs** (measured 2026-10-22, Bard lines a-1, a-2, b-1,
  b-3; `Outtake/bard-1-2/voice-tests/flash/` has Flash and the delivered v3 takes side by
  side for Thomas): ElevenLabs bills about 39% of the text's characters on
  v3 and 20% on Flash, consistently. Why is unknown, and it could change.
  At arcana-ai's $0.08 / $0.04 per 1,000 billed, an hour of fresh speech
  costs $1.58 on v3 and $0.43 on Flash. Flash made each line in 0.6-1.3 s,
  against v3's 3-4.5 s. Thomas is weighing what to do about voice cost
  (2026-10-22), and wants Flash tried.
  **Kokoro** (Kokoro-82M ONNX, tried 2026-10-22, `Outtake/bard-1-2/voice-tests/kokoro/`):
  preset voices only, no cloning. One CPU core makes about 1.7 s of speech
  a second (2.0 int8), four about 5. Thomas: better than expected,
  bm_fable acceptable, Flash only marginally better; they suspect Kokoro
  on a cloud server will cost more than Flash. Thomas thinks Flash may do
  for the DMs during a quest, and suggests players could choose a higher
  voice quality and pay for it (2026-10-22). **Voice quality, after
  launch** (@overlore, 2026-10-22, Thomas wants it): a character's setting,
  Flash by default, v3 for a player who chooses and pays; each request
  names its `model`, nothing new in mj. A stored v3 take plays for
  everyone, a Flash take only for Flash players. Overlore strips audio
  tags before Flash; none of its lines has any yet. **Flash reads tags
  aloud** (tested 2026-10-22, `Outtake/bard-1-2/voice-tests/flash-tags/`: Whisper heard
  "laughs", "whispers" and "sighs" in every tagged take, none in the
  plain); Overlore told.
  **Paid only** (Thomas, 2026-10-22): nothing should be generated unless
  someone paid for it. No price limit in mj, since one set too low would
  stop the game (Thomas, 2026-10-22). **Overlore already works this way**
  (@overlore, 2026-10-22, `mail/received/20261022-062817Z-*`): a coin is 5
  cents, a player pays twice mj's `usd`, and every paid request (a turn, a
  portrait, a snapshot) is checked first, refused once the player is 20
  coins (-$1) below zero. Room pictures are the house's cost (a player
  pays 2 cents a room). A lost reply is recorded nowhere and charged to
  no one; Thomas decided it isn't worth handling yet, so request ids in
  mj's ledger aren't asked for. Its sizes are far under mj's limits: the
  longest voiced line so far is 441 characters, a typed command at most
  500, a description 600, a voice note 60; no songs. Overlore takes
  pictures and clips back as base64, so `76e6f1e` changes nothing for it.
  Receipts per request were dropped (Thomas, 2026-10-22): an exploited
  Overlore sends, and would sign, as Overlore regardless.
  **`wait_seconds` on `shoot`** (asked by @overlore for Thomas, 2026-10-22,
  `mail/received/20261022-063221Z-*`): when Overlore stops waiting, mj
  drops the shot unmade and unbilled, as `speak` does. **Done in
  `1c33360`** (v0.13.0): no attempt or retry starts once less than the
  camera's typical time is left. Overlore waits 150 s for a picture and
  sends `wait_seconds: 120` with every line; told 2026-10-22
  (`mail/sent/20261022-064446Z-*`). **Overlore sends `wait_seconds: 150`
  on every shot** now (@overlore, 2026-10-22, `mail/received/20261022-070023Z-*`),
  and an overloaded reply's one try on the twin camera sends its own 150.
  Thomas questioned the typical-time margin (2026-10-22); mj explained it
  only drops a shot whose turn comes after ~140 s queued, and offered a
  fixed 3 s instead. Not changed.
  **Senders aren't checked on the bus** (found in the security review,
  2026-10-22): the server takes a REST message's `from` if it is registered,
  or empty, and a WebSocket's as written. Sent to @arcana at Thomas's word
  (`mail/sent/20261022-034813Z-@arcana--senders-aren-t-checked-*`).
  @arcana confirmed both paths (2026-10-22,
  `mail/received/20261022-041319Z-@arcana--re-senders-aren-t-checked-479affc7.md`)
  and is working out the fix with Thomas; it will say what mj's services
  and Overlore must change. **Where it stands** (@arcana, 2026-10-22,
  `mail/received/20261022-043901Z-@arcana--senders-where-it-stands-ee777ff8.md`):
  Thomas says the game's bus stays on 127.0.0.1. arcana 0.36.3 refuses a
  request whose `Origin` names another site or whose `Host` isn't this
  machine, which closes a browser page calling the bus. Programs send no
  `Origin`, so nothing changes for mj. **Thomas still has to install it.**
  Proving the sender (a key pair per project, a signed challenge at `join`,
  signed REST, a `verified` stamp) is designed in Arcana's `memory/keys.md`
  but not settled. Until then @arcana suggests a service's own check, such
  as a secret the game server passes in the payload; not pursued, for the
  same reason as receipts.
  **Built: arcana 0.37.0 and arcana-core 0.21.0** (@arcana, 2026-10-22,
  `mail/received/20261022-225657Z-@arcana--senders-can-now-be-proven-*`,
  corrected by `…225719Z-*`). Each project gets one Ed25519 key
  (`.ai/arcana.key`, machine-local); the bus keeps the public key and stamps
  a message `verified` when the sender holds `from`. For mj:voice and
  mj:camera: `shards update arcana-core` (the `~> 0.11` constraint already
  admits 0.21; the lock pins 0.18), then join with
  `key: Arcana::Key.load_or_create(...)` plus `owner_token:` once, which
  moves the address from the token to the key. A service can then serve
  only `envelope.verified` messages from addresses it expects. The bus
  refuses nothing yet, only logs `join.unproven` and `read.unproven`.
  **Thomas installed 0.37.0** (2026-10-24). arcana-core is updated to
  0.21.0 in `shard.lock` (not committed); it builds and the specs pass.
  mj:camera and mj:voice join with no token, so they are free addresses:
  the first key to claim one holds it, and another key then gets 409
  `held` (PROTOCOL.md, "Holding addresses"), so a lost key needs @arcana
  to free them. The user unit can't see the checkout's `.ai/`
  (`ProtectHome=tmpfs`), and the server has no `.ai/` at all.
  **Key: one per project** — Thomas already decided it (2026-10-22, in
  Arcana's `memory/keys.md`, "Decided"): `.ai/arcana.key` holds all of a
  project's addresses, @mj, mj:voice and mj:camera. My proposal of a key
  of mj-arcana's own is withdrawn. **Open:** the user unit would need
  that one file let in; a server has no `.ai/`, so the project key would
  be copied there (cyclops push, root 600, `LoadCredential=`) or the
  server makes its own; arcana's notes don't cover servers. **Asked
  @arcana** at Thomas's request (2026-10-24,
  `mail/sent/20261024-183110Z-@arcana--where-a-deployed-service-s-key-lives-*`).
  @arcana is taking it to Thomas, whose rule it is
  (`mail/received/20261024-204034Z-@arcana--first-mj-s-arcana.key-*`).
  **Decided by Thomas, 2026-10-24**
  (`mail/received/20261024-212014Z-@arcana--thomas-decided-a-service-has-a-key-of-its-own-*`):
  **each service has a key of its own**, made on first start and kept with
  its state, holding only its own addresses; `.ai/arcana.key` stays with
  @mj's sessions. arcana-core 0.21.1's `Arcana::Key.from_env` reads
  `ARCANA_KEY_FILE`. **Released in `v0.13.3`:** both units set it
  (`~/.local/share/mj/arcana.key`; `/var/lib/mj/arcana.key` on a server);
  on 2026-10-24 the local service claimed mj:camera and mj:voice, both
  proven, and replies come back `verified`. Gap: if a server loses
  `/var/lib/mj` while its bus keeps state, the addresses stay held until
  arcana adds a way to free them (tell @cyclops with the release).
  Overlore's game server gets its own key the same way (@arcana writes to
  it). In the earlier message: the 0.37.0 hook's exclude missed
  `arcana.key` in an `ai`-branch worktree, so git didn't ignore the key.
  It was never committed. Fixed in arcana 0.37.1 (released, not
  installed here). mj's `.ai/.gitignore` has listed it since `0344636`.
  **Callers: settled** (Thomas, 2026-10-24): no list on the workstation;
  a deployment locks to its own callers (e.g. overlore on the Overlore
  box). Built as `MJ_ARCANA_CALLERS` (`src/arcana/callers.cr`): set, only
  those addresses AND `verified`; unset, anyone. **Released in `v0.13.3`.** Runs
  here under "anyone" since 2026-10-24 (rebuilt, restarted, voices and
  cameras answered). Overlore's calls must sign before its box sets the
  list. Callers on the local bus
  2026-10-17..24 (audit log, `subject` = recipient, `object` = sender):
  overlore (the game server) 149 camera / 90 voice, @mj 11 / 34,
  @overlore 10 / 12, mj's own test addresses, owl 1; none `verified`, so
  refusing the unverified now would cut off the game. A handler sees
  `ctx.envelope.verified` and `from`.
  **OpenAI is retiring its speech models** (its deprecations page, notice
  2026-10-01, checked 2026-10-21): tts-1, tts-1-hd,
  gpt-4o-mini-tts-2025-03-20 and -2025-12-15 are removed 2027-01-06; the
  replacement named is gpt-realtime-2.1-mini (the Realtime API, not the
  speech endpoint). The page doesn't list the unpinned gpt-4o-mini-tts.
  Overlore's narrators pin -2025-12-15 (voice fable), so moving them to
  ElevenLabs now has that deadline. OpenAI is no overflow for voices.
  **Open, @arcana's:** does a speed-only `voice_settings` keep a voice's
  stored values or take the defaults? History shows each call's settings,
  but Henry, the Announcer and George all store the defaults, so it can't
  tell; settling it means changing a stored voice on Thomas's account
  (not done). Also: whether OpenAI counts tts-1's two added newlines.
