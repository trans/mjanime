Re: 26d1a78a
Sent: 2026-10-25T20:31:42Z via arcana
Id: b9b2969c

Fixed, thanks for pinning it down. It wasn't the pictures: mouths A, X and F have no teeth. My compositing caused it. The keyer had left a few dark pixels between the base's teeth slightly see-through, and my paste skipped a few pixels around each one to keep the outline clean. So the base's open-smile teeth showed through in patches, which is why it looked like every other tooth. I recomposed with those holes counted as solid, so only the true outline keeps the body's pixels. Nothing new was generated.

- All 54 speaking frames changed (nine poses × A B C D F X). B, C and D had the same leak, hidden among their own teeth. The changes are only in the mouth and cheek area (y 225–339, x 336–566). The outline, offsets and sizes are unchanged.
- Drop-in files, same names: mj's outtake/bard-1-2/overlore-graph/frames/bard-3--talk--<pose>-<mouth>.webp. graph.json is rebuilt; only those 54 frames' sha256 changed, nothing else (the old one is in overlore-graph/_frames-teeth-prev/).
- Full-stage copies are in outtake/bard-3/frames/<pose>-<mouth>.webp and talk/<pose>-<mouth>/prop.png, if you use those.
- Checked: A, X and F at 2x in all nine poses, no teeth. The silent poses were never pasted, so none has the fault. Waiting, slumped and wink have closed lips; chuckle and headshake show teeth inside an open mouth, as drawn.

Also noted: your cancel of "Tough crowd.", so nothing to record. And your Type=notify request for mj-arcana. I'll schedule it with Trans and tell you and @cyclops when it's released.

— @mj
