# Prompt slot order — what the providers say, and how to test it

*2026-10-13. Research done; the experiment ran 2026-10-14 (see Result). The order was then designed
in `picture-prompt-design-v1.md`.*

## Why this exists

DataDungeon's recipes split a picture prompt into seven slots, joined with one space:
**preamble · subject · description · theme · style · rules · staging**. I asked for `staging` to
move before the rules (`preamble · subject · description · staging · theme · style · rules`) and
they changed it in 0.13 before tagging. The argument was mj's established practice plus how
instruction-following reads — **not an experiment**, and the design says so.

Thomas has told `@owl` we'd do the analysis properly, after seeing whether the providers publish
guidance. This is that research, and a design cheap enough to actually run.

## What the providers publish

**Nobody publishes a slot order for images.** Not Google's image-generation page, not OpenAI's
image guide. The one real prompt guide is Google's (for Imagen), and it offers "subject, context,
and style" as "a good starting point" rather than a rule.

Three findings that bear on our order, two of which cut against it:

**1. Google's image examples put the medium FIRST and the lighting LAST.** Its photography advice
is to "Start your prompts with" *"A photo of…"*; its illustration template puts the art style ahead
of the subject (*"An [art style] of an angular sporty electric sedan…"*); quality words go at the
front (*"4k HDR beautiful photo of a corn stalk"*); and lighting is appended at the end
(*"studio photo of a modern arm chair, natural lighting"*). Camera terms go either way in its own
examples — *"A close-up photo of coffee beans"* before, *"photo of a leaf, macro lens"* after.

So Google appends lighting exactly where mj appends it today, which looks like evidence against
moving staging earlier. **It probably isn't**, and the reason matters: Imagen takes negative
prompts as a separate parameter, so there is no rules slot competing for last place. Google appends
lighting last because nothing else wants to be there. In mj the rules want it.

**2. Google says, for text, that constraints go FIRST — and that order matters.** Its prompting
strategies page: *"Place essential behavioral constraints, role definitions (persona), and output
format requirements in the System Instruction or at the very beginning of the user prompt."* And
directly: *"The order of the content in the prompt can sometimes affect the response"*, with advice
to test orderings. That is a provider telling us (a) this is real, (b) it is empirical, and (c)
their instinct for constraints is the opposite of ours. It is the text guidance, not the image
guidance — but Nano Banana is a Gemini-family model, so it is more than nothing.

**3. Edit models want preservation constraints LAST.** The FLUX.1 Kontext pattern, as the
API hosts document it, is one clear edit instruction followed by a suffix naming what must not
change — *"keep the [named elements] exactly the same."* That matches mj's own hard-won practice
for surgical edits (*"keep EVERYTHING identical, change ONLY <this>"*, techniques.md), and it
matters here because `base`, `decorate` and `pixelize` are all edit-from-reference operations.
Generation and editing may simply want different orders, which would be a finding worth having.

### A trap found on the way

OpenAI's guide says the Responses API image tool's mainline model *"will automatically revise your
prompt for improved performance."* If any mj camera goes through a path that rewrites the prompt,
**an ordering experiment on that camera measures nothing** — our slot order is destroyed before the
model sees it. Which path `dflare`/`dsunburst`/`dhero` take needs checking before they are included.
mj does not read a `revised_prompt` field anywhere today (`grep revised src/` is empty), so if one
comes back we are discarding it — which also makes `prompt_sent` a claim about what we sent rather
than what the model read. Worth telling `@datadungeon` if it turns out to be true for our path.

## The experiment

Two design problems to solve first.

**Attribution.** Reordering slots changes the prompt; so does sampling noise. **Only `klein`
honours a seed** (FLUX.2 Klein 9B, `runware:400@2`), so it is the only camera where the seed can be
held and the order is the only thing that moved. It is also the cheapest at $0.0059. Run the real
experiment there.

**Nano is the camera we ship, and it cannot hold a seed.** But it is believed deterministic — same
words, same picture (CLAUDE.md). If that is true, one image per cell is the correct sample size and
the nano arm is cheap. **Verify it first**: send one prompt twice, compare the file hashes. Two
calls, $0.14, and it decides whether the nano arm costs $0.41 or ten times that. This check is
worth having on its own.

**What to measure: compliance, not beauty.** Order plausibly affects *whether a slot is obeyed*,
and obedience is far more objective than preference. The rules slot gives a machine-checkable
target: a prop prompt's rules are "on a solid pure black background, nothing else in frame", and
mj's Tier-1 matte already flood-fills from the borders — so background purity and the count of
stray non-background blobs can be scored by code, with no judgement involved. If burying the rules
costs compliance, that shows up as a number.

Thomas judges the rest (style and theme fidelity), **blind** — filenames must not say which
arrangement produced which image.

### The arrangements

Four, chosen as targeted contrasts rather than a factorial (7 slots is 5040 permutations):

| | Arrangement | Why |
|---|---|---|
| **A** | preamble · subject · description · theme · style · rules · **staging** | what mj does today |
| **B** | preamble · subject · description · **staging** · theme · style · rules | the proposal |
| **C** | preamble · **rules** · subject · description · staging · theme · style | Google's text guidance |
| **D** | **style in the preamble** · subject · description · theme · rules · **light last** | Google's image examples |

Content held fixed: three real Silicon Circus subjects decomposed into the seven slots, one of them
`examples/prop/prop.yml` (which already reads as subject · description · style · staging · rules).

### Cost

| Run | Images | Cost |
|---|---|---|
| nano determinism pre-check | 2 | $0.14 |
| klein, 3 subjects × 4 arrangements × 3 seeds | 36 | $0.21 |
| nano confirmation, winner vs today, 3 subjects | 6 | $0.41 |
| | | **~$0.76** |

Three seeds on klein because a seed makes the comparison exact but one seed could flatter an
arrangement by luck; three is enough to notice that.

## Result (run 2026-10-14, `notes/slot_order.py`)

**Null, and clean.** 36 images on `klein`, four arrangements x three subjects x three seeds, $0.0993
including the seed check. Thomas's order was added as **E** (`rating · theme · style · subject ·
description · framing · light`) and **F** repeats it with the framing constraint hoisted to the
front beside the rating rules, so E vs F is the one clean test of Google's "constraints at the very
beginning" against our rules-last.

The seed check passed first: same prompt, same seed, twice, mean absolute pixel difference
**0.0000**. Identical files, so within a pair the slot order really is the only thing that moved.

| arrangement | border mean | border max | lit share |
|---|---|---|---|
| A (DataDungeon's original) | 2.058 | 8.0 | 0.358 |
| B (staging mid, rules last) | 1.841 | 7.9 | 0.349 |
| E (Thomas's) | 2.177 | 8.6 | 0.337 |
| F (E, framing hoisted first) | 2.388 | 9.1 | 0.322 |

A spread of 0.5 on a 0-255 scale, with n=9 a cell. That is noise, not an effect.

**Both rules were obeyed in all 36.** The background is solid black everywhere and nothing else is
in frame; and — the harder one — **no text, letters, numbers or signage appears in any of the 36**,
including nine ticket booths, which is the subject most likely to invite a sign.

**The test was not sensitive, and that is the real finding.** No arrangement ever broke a rule, so
there was no variance for order to explain. These are lean prompts, seven short slots, two
unambiguous rules, and a model that obeys them from any position. To detect an order effect you
would have to put a rule under pressure it can actually lose to: a longer prompt, slots that
contradict each other, or a rule mj is known to break — "no signage" fails in practice on venue
prompts that name a venue, and no venue was named here.

### By eye (Thomas, 2026-10-14)

"Other than the fact that the wheels were in the wrong place in most of those teapot carts, nothing
looks particularly wrong in any of them." Which closes the eye-half of the test the same way the
machine half closed.

The misses are worth recording, because none of them is a rule: the two *prohibitions* held
everywhere, and everything the model got wrong was a positive instruction.

| instruction | result |
|---|---|
| "a **two-wheeled** popcorn cart" | four wheels in 4 of 12 |
| "a **folded** parasol at the back" | open in 10 of 12 |
| "a brass **kettle** inside" | a teapot in 12 of 12 |

**And the defects track the SEED, not the arrangement.** Seed 141421 draws four wheels under A, B, E
and F alike; seed 31337 is the only seed that ever folds the parasol, and it folds it in B and E.
When this model gets something wrong, reordering the slots does not fix it and reseeding does. That
is a better argument for the null than the border statistics are.

"Teapot cart" is the diagnosis as well as the nickname: "brass kettle" reads as a teapot, so every
one of the twelve drew a teapot. Word choice beat slot position by a distance — which is the house
line about lean prompts, arriving from a direction nobody aimed at.

**This also names the sensitive test.** "Two-wheeled" and "folded" are instructions this model
demonstrably loses, so a v2 that walks THOSE through the slot positions would have real variance to
explain, where v1 had none. Same harness, same cost, one changed constant.

**So the order is free to be chosen for other reasons.** That is the fallback this note predicted,
and DataDungeon's reason now carries it unopposed: pick the order that makes `prompt_sent` equal to
the fields joined, so it is not stored twice. Thomas's **E** does that and reads correctly besides
(rating, world, medium, subject, particulars, shot). Nothing in the measurements argues against it.

Bounds on the null: `klein` (FLUX.2 Klein 9B) only, 1024x1024, text-to-image with no reference.
Nano, the camera we actually ship, is untested — and so is editing, where the Kontext evidence
points at preservation-last for a different reason. Note also that the harness calls Runware
directly, where `klein` does accept text-to-image; mj's own transport has no text-to-image route
and feeds a flat grey canvas instead (`src/arcana/transport.cr:69`), so production prompts arrive
with an image attached. Worth repeating through the service if the question ever turns sharp.

Spend: **not in mj's ledger** — the harness calls Runware directly.

## What this can and cannot settle

It can settle whether slot order changes rule compliance on one FLUX model and one Nano, for prop-
shaped prompts. It cannot settle it for the OpenAI cameras (prompt revision, unverified), for edit
operations (different prompt shape, and the Kontext evidence points the other way), or in general.
If A and B are indistinguishable, that is a real result too: the order can then be chosen for
`prompt_sent` reconstruction alone, which is the argument DataDungeon already accepted.

## Sources

- https://ai.google.dev/gemini-api/docs/image-generation
- https://ai.google.dev/gemini-api/docs/prompting-strategies
- https://docs.cloud.google.com/vertex-ai/generative-ai/docs/image/img-gen-prompt-guide
- https://developers.openai.com/api/docs/guides/image-generation
- Kontext preservation pattern via API hosts (Prodia, Vercel AI Gateway); the official
  `docs.bfl.ai` guide was not reachable — 404 on the URL tried, and not in the search index.
