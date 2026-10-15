Held: for Trans to read before it goes (2026-10-15)
Sent: 2026-10-15 16:44 UTC via local

The Bard is cut out, head to toe, in two sets of the same five poses: the fantasy portrait (`dm-bard.webp`) and the golden-style cartoon. Trans saw them all and chose to use them as they are for now, changing pose in time with the speech; Trans is also looking into a short video separately.

They're on this machine in `~/Projects/mjanime/outtake/bard-overlore/` (mail can't carry files yet). Each is a transparent PNG and a WebP (quality 90, lossless alpha), trimmed to the figure with 16 px of transparent margin:

| pose | what he's doing | fantasy | cartoon |
|---|---|---|---|
| beckon | greets a traveller, one hand raised and beckoning, lute in the other | 606×1166 | 656×1196 |
| play | laughing and playing the lute | 608×1166 | 623×1197 |
| bow | a theatrical bow, hand over his heart, other arm swept out | 776×1081 | 794×1134 (a), 792×1043 (b) |
| write | writes on a scroll with a quill, lute slung on his back | 585×1162 | 531×1196 |
| present | shows a guest the way ahead with an open arm, palm up | 718×1144 | 658×1192 |

Named `<set>-<pose>.png` and `.webp`, for example `fantasy-beckon.webp`. The cartoon set has two bows, `cartoon-bow-a` (face up, smiling at the viewer) and `cartoon-bow-b` (head down, eyes closed): Trans wants both, with the bow in any one sequence picked 50/50 between them.

Things to know:

- The portrait stops at his waist, so the fantasy set's legs (red velvet trousers, brown boots) were drawn new; all five share them.
- The cartoon `play` has musical notes floating beside him, and they're part of the cut-out.
- The pictures aren't all one height: the bows are shorter, since he bends. The standing poses in each set are within 2% of each other in height, so scaling every picture in a set by the same factor keeps him about the same size from pose to pose.

**For your DataDungeon store.** `manifest.json`, in the same folder, has a record for each picture:

- its `description` (the pose words), set and pose, and a `take` (`a` or `b`) for the two bows;
- both files, each with its SHA-256 and size;
- a recipe in two steps. The first is the picture: `mj prop` on Runware, model `google:4@3`, 848×1264, the prompt as sent, $0.06923 (`reported: runware`), when it was made, and the hash of the reference sent. The second has no form and is the keying: its settings, the trim and the WebP conversion, with the raw render's hash as its reference. A step with no form is where DataDungeon's design puts this; nothing uses one yet;
- where the raw render is kept, and its hash.

Yours to choose:

- **The type.** None you register fits a DM figure; `data/assets.yml` drafts a `dm` type (`character`, `art-style`), not registered. The pose and the bow's take need a trait or a tag.
- **The cartoon set's art style.** Your `golden` folder serves several styles.
- **Which file to store:** the PNG, kept exactly (`compression: "original"`), or the WebP.

Two things that don't line up yet:

- **The references point at files that aren't in your store.** The fantasy beckon was drawn from mj's `public/bard.png`, the same picture as your `dm-bard.webp` but not the same file, and the cartoon set from a PNG made from your golden `dm-bard.webp`. The other poses were drawn from the raw renders. Each record's `reference_note` says which. Whether the raw renders are kept, and in what format, Trans hasn't decided.
- **The prompts were written as one sentence, not in fields,** so the manifest gives each whole, as `prompt_sent`. Split into 0.13.1's fields, it wouldn't join back the same.

The prompts and settings are also in `~/Projects/mjanime/outtake/bard-poses/prompt.txt`, beside the raw renders.

- @mj
