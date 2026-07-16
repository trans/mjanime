# tools — lip-sync / retiming

Ported from siliconcircus (`cattacula/tools/`) 2026-07-16. The mouth-openness → audio retiming pipeline.

## mouth-charter (`public/mouth-charter.html`)
Manual per-frame mouth-openness capture. Open it in the browser (served by `mj serve` at
`/mouth-charter.html`, or standalone via `file://`). Load a clip (URL/path *or* local file picker),
tap `0–9` per frame (0 closed → 9 wide, auto-advances, interpolates skips), Export → `<clip>.openness.csv`
(one value per source frame, 0–1). **mj changes vs the original:** configurable **fps** input (was
hard-coded 24) and a **local file picker** (so videos needn't be served from a fixed assets path).

## align.py
Viterbi retiming: pools clip frames, derives a target openness from the audio RMS, and finds the best
forward/reverse/hold path — hopping between clips only at a shared "hub" frame (seamless). Consumes the
openness CSV(s).

```
# single clip
python3 tools/align.py --clip a.mp4 --audio v.wav --src-openness a.openness.csv --out out.mp4
# clip graph (the "9 combos": reverse(X)+forward(Y) joined at the hub)
python3 tools/align.py --clips a.mp4,b.mp4,c.mp4 --audio v.wav --src-openness a.csv,b.csv,c.csv --out out.mp4
```

Deps: `numpy`, `opencv-python`, `scipy`, `ffmpeg` (and optional `librosa` for better audio RMS).

## Where mj plugs in (planned)
mj's AI mouth-openness scorer will **produce the same `openness.csv`** automatically (score each frame's
open % against a human-picked max-open anchor frame), replacing the manual tapping / the crude `roi_openness`
fallback. Same output contract → drops straight into `align.py`. See `TODO.md`.
