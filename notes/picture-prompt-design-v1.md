# Picture prompts — who writes what, and in what order

*2026-10-14. Designed with Thomas in conversation; not built. Put to `@datadungeon`, `@overlore` and
`@owl` 2026-10-14. Follows `prompt-slot-order-v1.md` (the research and the first order test) and the two
cow tests (`cow_order.py`).*

*DataDungeon answered 2026-10-15, after going through it with Thomas (`.ai/mail/received/20261015-003151Z-@datadungeon--re-picture-prompt-design-f58634bb.md`).
Where it differs from what follows: `directives` replace `changes` and also take the kind's own rules
("each named thing drawn once", "keep their face, hair and clothes"), so `rules` at the front are only
the fixed ones, the same for every picture; a fixed rule must not contradict a description ("no text
unless the description asks for it", Thomas); there is no kind setting, because the asset's type and
the app's tag already say it. The order is now **rules · framing · style · theme · subject ·
description · staging · light · directives**. DataDungeon 0.14 (built 2026-10-15, `c76640e`, not
tagged) adds `flavor` after `style` (Thomas): `style` is DataDungeon's own words for the art style,
`flavor` the app's wording refining it.*

## Why this exists

DataDungeon 0.13's picture order, **preamble · subject · description · staging · theme · style ·
rules**, is the one mj asked for on 2026-10-13. It came from mj's habit of ending prop prompts with
"nothing else in frame", not from guidance or measurement. The slot-order test then came back null on
`klein`, which freed the order to be chosen on other grounds.

Thomas's direction (2026-10-14): follow whatever guidance the image-model makers publish, and build the
design on **how pictures are made in the game**, in real time, not on how we hand-craft prompts here.

## How the game makes pictures today

From Overlore (`infocomics/src/overlore/`), checked 2026-10-14:

- **The DM writes words and code builds the prompt.** Every turn the DM model must call one tool,
  `comic_panel` (`dungeon_master.cr`), filling `description` (the panel: pose, action, "where each
  figure is and which way they face", mood, lighting), `room` (the room as it looks now) and flags
  such as `hero_shot`. Code then wraps those words in fixed parts (`image_prompts.cr`).
- **A room's first picture** is drawn from the DM's `room` text, on `flare` with the neighbouring rooms'
  pictures as references, or on `klein` with the theme's seed when no neighbour has one
  (`web_app.cr`, `web_app/rooms.cr`).
- **A room in a new state** (same room, now a thief is here) is an edit. A picture is keyed to the
  game's text for the room; when that text no longer matches, a small model compares the two texts and
  writes one instruction (`data/room_change.md`), and `kontext` edits the room's most-used picture
  with that instruction plus "Everything else in the picture MUST stay exactly the same."
- **Room layers** (behind `--room-layers`): objects drawn into an empty backdrop one edit at a time,
  kept as cut-outs.

Thomas: the Overlore side is "a bit hodge-podge"; there is work on both ends.

## Who supplies what

Decided with Thomas, 2026-10-14:

- **The DM uses words.** Words are its strength; it needs guidance on what to say, not numbers. It
  never gives yaw, pitch or ground lines: those are **post-processing**, measured from the finished
  picture.
- **The DM is responsible for subject, description and staging** — and for the subject it *names*
  who or what; the stored appearance (the hero's character description, a portrait) comes from code,
  so a character looks the same in every picture. Its request is structured, through a JSON schema
  (`{subject, description, staging}`), however the record is later stored.
- **Rules are fixed,** set by code: the standing rules for every picture (no text, no signature, what
  the rating allows), per asset type, plus extra rules per kind of picture (a room picture: "each named
  thing drawn once"). Not written by the DM; the DM knows what kind of picture it is asking for, which
  may shape its words, but nothing depends on it saying "no other people".
- **Style and theme come from the game's state.** The DM does not choose them. **Mood is thematic**
  (Thomas): it belongs with the theme.
- **Light comes from the place.** A room's picture is post-processed once for its light; a new
  picture set in that room inherits it, so a panel matches its backdrop without the DM saying so.

## The order

Rules first (Thomas). Four groups, each from one source:

| group | fields | supplied by |
|---|---|---|
| **spec** | rules · framing | code, by kind of picture (room, panel, hero shot, portrait) |
| **look** | style · theme (with mood) | the game's state |
| **object** | subject · description · staging (with view) | the DM (subject's appearance from code) |
| **relation** | light · changes | the pictures that already exist: the room's measured light, the picture being edited or used as a reference |

> **rules · framing · style · theme · subject · description · staging · light · changes**

Two placements to be clear on: **mood is part of theme** — there is no mood field — and **view is part
of staging** — there is no view field; the DM says it in words, inside its staging.

Why each sits where it does:

- **Rules first.** Google's prompting guide puts "behavioral constraints … and output format
  requirements … at the very beginning of the user prompt", and the start and the end are the strong
  positions of a prompt (the "lost in the middle" finding, from text models). Thomas chose first.
- **Framing with rules,** not with style or staging: code sets both from the kind of picture, and the
  kind bounds what staging may do, so it comes before it (the photographer knows it is a portrait
  session before posing anyone).
- **Style, then theme.** Order of lessening constraint: style governs every pixel, theme the world.
- **Light after the object.** Thomas: a photographer has the subject, sets the pose, then lights it;
  light means little before there is something to light. Google's image examples also append lighting
  last ("…, natural lighting"). And DataDungeon stores light in the picture's frame, so "from the
  left" only means something once the view (staging) is set.
- **Changes last: the end holds what the picture is for** (Thomas). In an edit, the change; in a new
  picture drawn from a reference, the change from it; in a picture drawn fresh, `changes` is empty and
  the object and its light end the prompt. The edit models' own pattern puts "keep X the same" last
  (FLUX Kontext), Overlore's room change already has that shape, and Nano let the last instruction
  win (below).

The groups bleed into each other at their edges — framing into style, theme into subject, staging into
light through the view (a bird's-eye view decides how light reads) — which Thomas took as a good sign.

The groups also match what DataDungeon does with a stored picture: the **object** is what semantic
search should index; the **look** and **spec** are filters; the **relation** is provenance (Overlore
already stores `derived-from` and `drawn-with` links).

## The fields

**The kind of picture is a setting, not a field.** A portrait, a room backdrop, a comic panel, a
hero shot: code picks it from what the DM asked for (a hero shot spent, a picture token, a room
entered) and it is stored on the recipe as a setting. It is the template the rest hangs on: it decides
the extra rules, the framing words, and **what staging may do** — you don't ask for an action scene
when the kind is a portrait (Thomas). So each kind comes with its own staging guidance for the DM, the
"little bit of guidance" it needs. DataDungeon's asset types already carry the coarse part (a room
backdrop is a `drop`; a panel or a hero shot is a `plug`, "a framed moment"). Not called `template`:
DataDungeon's draft types use that for text with `{{slots}}`, and mj for `template.png`.

- **rules**: what every picture must obey, fixed by asset type, plus extra rules by kind of picture.
- **framing**: the words the kind contributes to the prompt — how much is in frame and the overall
  shape: "a wide landscape", "full body, head to toe", "a close-up". Replaces `preamble` ("preamble"
  says where the words go, not what they are). Thomas chose `framing` over `shot`, which named the kind
  and the words in one field. Not `format`: a picture recipe's settings use that for the file type.
  Framing is not the view: where the camera stands is staging's. (DataDungeon's notes once said "the
  hero's framing (from behind, a profile)"; in these fields that is staging.)
- **style**: how it is drawn.
- **theme**: the world, **including its mood**. Mood is thematic (Thomas), so it lives here, not in a
  field of its own and not with light. A room whose atmosphere differs from the game's (an eerie
  cellar in a cheerful game) says so in its description.
- **subject**: who or what it is of. The DM names it; code supplies the stored appearance.
- **description**: what is happening, what is different about the subject this time (a wound, a
  soaking), what is there.
- **staging**: where each figure is, which way it faces, and **the view** — where the camera stands
  (straight on, three-quarter, from behind, a bird's-eye view). The view is part of staging, in the
  DM's words; a view vector is only ever measured afterwards. Staging works within the kind of
  picture: what the kind fixes (a portrait's full-body framing and front-facing pose) is not staged;
  what it leaves free (in a panel, close on the hand or wide on the whole room) is.
- **light**: the standing light, inherited from the place's post-processing.
- **changes**: what this picture changes, and what it keeps, relative to an existing picture. Edits
  ("add a thief by the door; everything else stays exactly the same") and reference shots ("the hero
  from the reference image … keep their face, hair and clothes"). **A change to the light** (a lamp
  lit, the lights going out) **is a change** and goes here, not in `light`.

Case B written out, to see that it reads:

> *[rules] [framing] [style] [theme]* The hero from the reference image. Climbing a knotted rope down
> into a cellar. On the left of the frame, facing away from the viewer. Lit from above and from the
> left. Keep their face, hair and clothes exactly as in the reference image.

## Conflicts are settled in code, not by order

When the DM adjusts something inherited (the room's light, then "a lantern flares up"), the prompt
must not carry both. Order does not reliably settle a contradiction — it depends on the model — so code
replaces the inherited value before the prompt is built. Each property has one value, the prompt cannot
contradict itself, and the record says what was actually used.

The evidence, the cow tests (2026-10-14, through `mj:camera`, 1024×1024, three runs per cell — small;
`klein` seeds 31337, 8675309, 141421; `nano` and `flare` take no seed). Pictures in `outtake/`
(not committed); harness `cow_order.py`.

**v1, a contradiction in both orders** ($0.5347):

| camera | "…Draw a cow in the field. Don't draw a cow in the field." | "…Don't draw a cow in the field. Draw a cow in the field." |
|---|---|---|
| klein (FLUX.2 Klein) | cow in 3 of 3 | cow in 3 of 3 |
| nano (Nano Banana 2) | cow in 1 of 3 (small, far off) | cow in 3 of 3 |
| flare (GPT-Image 2.5) | cow in 3 of 3 | cow in 3 of 3 |

**v2, the "don't" alone, against a control** ($0.5346): "Draw a field. Don't draw a cow in the
field." and "Draw a field." — no clear cow in any of the 18. With the seed held, `klein`'s pictures
barely changed when the "don't" sentence was added (9.8% mean pixel difference on two of three
seeds).

So: on `nano` the later instruction won 5 of 6. On `klein` and `flare` "draw X" beat "don't draw X" in
either order, and a "don't" alone drew nothing — naming a thing to forbid it was harmless there, but
any positive mention anywhere wins. Which is why conflicts are resolved before the prompt, and why a
rule like "no people" is at risk whenever a description mentions a person.

## View and light as words

The DM says the view in words ("seen from straight on"). Vectors are post-processing. DataDungeon owns
turning `view` and `light` into words, since it owns the vectors and their conventions
(`DESIGN-image-fields.md`): mj's `src/arcana/view.cr` was handed to them 2026-10-14
(`.ai/mail/sent/*-@datadungeon--view-words.md`). mj may later offer it as a bus tool for apps that do
not use DataDungeon, wrapping their code rather than keeping a second copy (`TODO.md`).

## mj's part (under review)

Thomas's view (2026-10-14): **mj sends exactly the prompt it is given.** Deciding what is asked of the
generator is the calling app's job, following these heuristics (or DataDungeon's join, which already
does the joining). DataDungeon's field names should not reach into mj's interface. What mj owes in
return is drawing exactly what was asked, and **publishing how each camera behaves** (as `cameras`
already publishes measured cost, speed and sizes), so the app can apply the heuristics. If this holds,
the `prompt_parts` and staging-order TODOs are moot.

## Side findings

- **Nano did not give the same picture for the same words.** Repeats of one prompt differed by 13–19%
  mean pixel difference. CLAUDE.md rule 6 says "Same words → same picture"; not so here, through
  Runware, 2026-10-14.
- **The grey canvas shows through.** mj's Runware transport has no text-to-image route, so an
  unreferenced shot edits a flat grey canvas (`src/arcana/transport.cr`). It survived as a flat grey
  sky on `klein` seed 31337 in 3 of 4 prompts, and once on `flare`. Overlore's seed camera is `klein`.

## A prompt as a template (Thomas, 2026-10-16; being worked out)

Thomas's first reason for the fields was storage: the same words repeated in every record. Measured
on mj's own 459 prop prompts (`outtake/prompt-dedup/`), storing each distinct sentence once leaves
51%, and zlib with a 32 KB dictionary leaves 22%, so fields are not the best tool for bytes alone.
Most of what fields hold is a registered choice anyway: rules (by rating), framing and the kind's
own rules (by kind), style, flavor, theme, a stored character's appearance, and light (computed from
the place's measured direction). What is written per picture (description, staging, an edit's
change) is small. And a hand-written prompt (the Bard's, 2026-10-15) doesn't split into fields
cleanly, though a rewrite in field order drew a usable picture (`outtake/bard-field-order/`).

So Thomas's idea: **one prompt field, with Mustache tags for the registered parts** (Mustache because
DataDungeon already uses it for Overlore's decrees; `$` turns up in prompts). Code writes the bare
tags around the DM's words, `{{rules}} {{framing}} {{style}} … <the DM's words> {{light}}
{{kind-rules}}`, a bare tag taking its value from the asset's category. DataDungeon pins each to the
exact wording when it stores the prompt. The asset's category says what it is and may change later;
the stored prompt says what was sent and doesn't. That replaces the field order (each prompt has its
own), the custom flag (a prompt with no tags is just text) and the stored whole prompt.

Proposed to `@datadungeon` 2026-10-16 and **accepted** the same day, after Thomas went through it
with them (`.ai/mail/received/20261016-174214Z-@datadungeon--re-proposal-prompt-as-template-97f4d8dc.md`).
Built in 0.14, before the tag, for every form (speech too), so the field orders go entirely.
References are full names, `{{style datadungeon:golden-comic@1}}`, not row ids (Thomas: ids save
about 108 bytes a prompt, and compression can come later without changing the format). Bare tags
wait for 0.15's standard `art-style` and `rating` tags; until then the app names the wording. Light
and the view are plain words, not tags: the app puts `ViewWords`' output in as its own text, since
pinning a version of code would mean keeping every version. A table of references, written when a
prompt is expanded, keeps lookups by wording indexed. A character's appearance is a named text in
field `character`; a literal `{{` in an app's words is refused. Open: a naming rule for an app's
wording of a rating (`overlore:g`?).

Later the same day (`.ai/mail/received/20261016-194736Z-@datadungeon--re-wording-versions-as-hashes-f3cbc3d8.md`):
a wording's version is a hash of its words, not a number, because each store numbered versions
itself, so `@2` could mean different words in two stores. It is the first 10 hex characters of the
SHA-256 DataDungeon already keeps for every text. Wordings can't be changed or deleted once they
exist (triggers), and a rename is a new name. Thomas decided: DataDungeon's owner is `dd`; standard
styles stay `dd:`'s; and style and flavor are one tag, `{{style dd:silver-comic overlore:place}}`,
stored as `{{style dd:silver-comic@6e21dec2ab overlore:place@ad346239b4}}`. So a flavor's name is
its purpose, and the `/purpose` part of a name goes.

## Open

- **Rules at the front, measured.** Overlore's mailbox check (`image_prompts.cr`, 2026-10-14) found
  "each thing once" held better last than in the middle; the front was never tried. Front vs end on
  that prompt, `klein`, seed held: cents.
- **mj sending the prompt as given**, and what `shoot` does with `view`/`light` meanwhile.
- **What room post-processing can measure.** A vision model can probably name time of day; a light
  direction from a stylised picture is harder. Test before relying on it.
- **Other characters' appearance.** The hero has a stored description; whether the troll does is
  unchecked. Without one it is described fresh, and looks different, every time.
- **DataDungeon's migration.** Records stored as "sent as joined" must keep their old join when the
  order changes (their handoff note); the `preamble` → `framing` rename, the new fields and the kind as a setting are best done in the
  same release.
- **Each kind's staging guidance**: what the DM may stage under a portrait, a panel, a hero shot, a
  room — to be written with Overlore. The DM has to know the kind before it stages, but today it sets
  `hero_shot` in the same `comic_panel` call where it writes the description; a tool per kind, each
  with its own staging guidance, would make choosing the tool choosing the kind.
- **For `@datadungeon`, from Thomas:** what is the `template` property in `DESIGN-types.md` (text
  with `{{name}}` slots) for? Thomas wants to know.
- **Overlore's builders** need mapping onto these fields; today `rules` also carries the room rules and
  the edit's "everything else stays the same", which belong in the spec and in `changes`.
