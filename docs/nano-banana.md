# Nano Banana — the image model mj leans on

Almost every image mj produces comes from **Google "Nano Banana"** (Gemini image models)
on **Runware**, called through `RunwareClient#edit_references`. Understanding how it behaves
is the difference between one good roll and five wasted ones.

## Model versions (Runware AIR ids)

| AIR id | What it is | Use it for |
| --- | --- | --- |
| `google:4@1` | Original Nano Banana (Gemini 2.5 Flash Image) | **Avoid.** Deprecated, edit-biased — it will **not** do a global restyle (asked for "16-bit pixel art" it just re-renders faithfully). Accepts only `referenceImages`. |
| **`google:4@3`** | **Nano Banana 2** (Gemini 3.1 Flash Image) | **The default.** Restyles properly, cheaper, native ultra-wide aspects. This is what every current spec uses. |
| `google:4@2` | Nano Banana Pro (Gemini 3 Pro Image) | When a scene needs stronger **lighting / camera** reasoning. Pricier. |

> If a restyle "won't take" (pixel art comes back looking like the photo), first check you're
> not on `4@1`. Then check the prompt (see [under-stylization](techniques.md#the-pixel-recipe)).

Full API dumps: `notes/google-nano-banana-2.md`, `notes/google-nano-banana-pro.md`.

## How `edit_references` calls it

`edit_references(reference_bytes : Array(Bytes), prompt, width, height, model)` →
Runware `imageInference` task with:

- each reference image uploaded → `inputs.referenceImages` (array of UUIDs)
- `positivePrompt`, `width`, `height`, `outputType: URL`, `outputFormat: PNG`
- **no seed, no strength, no CFG, no steps, no session field**; a fresh `taskUUID` each call.

That last point matters — see *statelessness* below.

## Behavior you must design around

### It is a deterministic instruction-follower, not seeded diffusion
Nano Banana is a Gemini image model. **Same words → ~same picture.** It is *not* a
diffusion model you re-roll for variety by changing a seed (we send no seed anyway).

- **Want variety? Change the WORDS.** Or route through an actual diffusion model + seed.
- **Myth busted:** Nano has **no cross-call memory.** Repeated look-alike venues were caused
  by us sending the *same detailed prompt* each time (or the same boxy template), not by the
  model "remembering". A bare prompt like *"A Christmas gift shop tent."* gives a totally
  different tent every time — zero bleed.

### The reference image steers the output (it is not inert)
The edit model needs *an* image. Whatever you feed it **tints and shapes** the result:

- A **drawn template is a straitjacket** — Nano traces its silhouette. A boxy template → a
  boxy building. Bright/coloured template → flat cartoon output (it copies the template's
  *style*). See [templates](techniques.md#templates--a-rough-reference-not-a-cutter).
- For **organic / ornate** subjects, feed a **blank chroma-green canvas** and let the prompt
  drive. Reserve drawn templates for genuinely geometric subjects.
- A **neutral grey massing template** gets Nano to obey the prompt *and* leaks grey into the
  building material (grey template → grey concrete) — sometimes exactly what you want.
- To **edit one thing** (fix a word, relight), feed the previous **render as the reference**
  and say "keep EVERYTHING identical, change ONLY …". Back up `render.png → render-v1.png`
  first.

### Fixed dimension set
Nano accepts only a **fixed set of dimension pairs**. `edit_references` passes width/height
straight through (no FLUX-style snapping), so an unsupported size is a hard **400
`unsupportedDimensions`**.

- 16:9 landscape → **`1376×768`** (NOT `1344×768` → 400).
- Other supported pairs seen: `1024×1024`, `1200×896`, `896×1200`, `1264×848`, `848×1264`,
  `1184×864`, ultra-wide `1548×672` (21:9), up to 4K, etc.
- **Recipe:** generate at the nearest supported size, then resize the keyed output to the
  venue's canonical dims (`magick … -resize WxH!`; use `-filter point` for pixel assets so
  they stay crisp). Pick **one canonical dim per venue** for day/night/pixel registration.

### Text / signage
Nano Banana 2 renders sign text fairly well. But **it invents signage** if you over-specify
an interior ("CAFE", "LIBRARY" …) — which makes false promises to the player. Name only the
identity sign; let it invent the rest. For pixel art, the [pixelize](tools/pixelize.md) prompt
carries a **text-exception** so lettering is pixelated straight, not redrawn as mush.

## Prompt craft (the short version)

- **Lean prompts.** Direction + a few must-haves, not an enumerated checklist. Over-specifying
  (a) paints things nobody asked for, (b) **drifts the concept** (1900s newspaper → fairytale
  castle), (c) invents false signage.
- **Name the ONE focal piece** and the identity sign; let Nano invent the rest.
- **Never write "standing on the ground" / "on the ground"** — it adds a floor. Say
  *"floats isolated, no ground / no floor / no people"* for a clean prop cut.
- **Style vocabulary is loaded** — some words sabotage a realistic render. See the
  [banned-words table](techniques.md#style-vocabulary--words-that-sabotage).

---
Related: [techniques](techniques.md) · [world](world.md) · [`mj prop`](tools/prop.md) ·
[`mj pixelize`](tools/pixelize.md)
