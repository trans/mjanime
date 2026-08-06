# Shadow Box in mj — Plan (draft 2026-08-05)

Bring the Silicon Circus **shadow box** (parallax depth-layer dioramas) into mj as a generalized,
first-class tool. Source today: `~/Projects/siliconcircus.lol/pirateship/public/shadowbox/`
(`index.html` = drift *player*, `sbedit.html` = *editor*), Three.js r170, reads a hand-kept
`assets/manifest.json`, exports/loads scene JSON.

## Status (2026-08-06)

- **P0 ✔** scaffold (name-centralized tool, vendored three, drift stub) — `fe3e499`
- **P1 ✔** asset bridge (palette from prop + backdrop libraries, /lib image routes) — `18b988b`
- **P2 ✔** editor port (sbedit → `shadowbox.ecr` + `shadowbox.js`, under mj nav) — `6455175`
- **P3 ✔** scenes library (save/open/delete by name, `SceneLibrary`) — `e216f99`
- **P4 ✔** standalone player (`/shadowbox/play/<name>`, drift + walk-through, embeddable)
- **P5 ☐** polish — `.webp` option, backdrop import, optional `mj scene`/bus surface

generate → compose → play is now complete end-to-end.

## Why it belongs in mj

mj is a *generator* (props, backdrops, strips, sfx, voices). It has no *composition/output* stage.
The shadow box is exactly that: **generate → compose → play**. Every `cut:true` palette image is a
prop of the kind mj already makes, so the prop library (built 2026-08-05) is the upstream of this.
This makes mj an end-to-end studio instead of a bag of generators.

## The concept (unchanged, just generalized)

A scene is a stack of image planes at real depths in a box. Backdrop far back (oversized to overfill
the frame at its depth, so drift can never reach an edge — "band problem gone by construction"), props
at mid/near depths. Camera never walks, only **drifts**; the parallax between layers is the whole
effect. Alignment rests on two facts already in the editor: **horizon** (every image's baked eye-level
sits at world y=0) and **scale** (the image reproduces its shot FOV when it subtends the same angle —
scale *is* the FOV knob). **Floor** seats grounded props; each carries a soft contact shadow.

## Target architecture in mj

```
Palette  ─ GET /shadowbox/assets.json ─ aggregates:
             • prop library   (index.json)      → cut:true
             • backdrop library (index.json)    → cut:false
Images   ─ GET /lib/props/<name>.png , /lib/backdrops/<name>.png   (libraries live outside public/)
Editor   ─ GET /shadowbox            → src/views/shadowbox.ecr + public/js/shadowbox.js
Scenes   ─ filesystem library  ~/.local/share/mj/scenes/<name>.json  (Config.scenes_dir)
             GET/PUT/DELETE /shadowbox/scenes[/<name>]
Player   ─ GET /shadowbox/play/<name> → drift/parallax viewer (no editor chrome), embeddable
Vendor   ─ public/vendor/three.module.js  (r170, re-vendored)
```

Scene JSON (portable, standalone — see design goals):
`{ name, meta:{}, floorY, lens, cam:{x,y,z,yaw,pitch},
   layers:[{src,w,h,x,y,z,scale,horizon,shadow, meta:{}}] }`
— `src` is an mj-served `/lib/...` URL; `meta` is an open object (scene-level and per-layer) for
arbitrary custom data. A scene is self-describing and relocatable.

## Design goals

- **The scene JSON + assets are the deliverable; the player is just one consumer.** Other programs can
  copy the player and the format and adapt it. So the format stays small, documented, and free of
  mj-only assumptions, and carries open `meta` fields (scene + per-layer) for custom info.
- **Name is not hardcoded.** The tool identity (URL slug + display title) lives in ONE place
  (`MJ::Shadowbox::SLUG` / `TITLE`); routes and nav derive from it. Renaming to "Diorama" later is a
  one-line change (plus a couple of file renames), not a find-and-replace. (Naming still debated —
  "Shadowbox" for now.)
- **Everything mj-served, same-origin, no external hosts** — CSP-clean, works offline.

## Phases

**P0 — Scaffold.** Re-vendor `three.module.js` → `public/vendor/`. Add "Shadow Box" nav link in
`layout.ecr`. Empty `get "/shadowbox"` route + `shadowbox.ecr` stub. (Proves the plumbing.)

**P1 — Asset bridge (palette from mj libraries).**
- `Config.scenes_dir` + decide the **backdrop source** (see open decision #1). Add a `backdrops`
  library mirroring the prop library shape (folder or flat + `index.json` with w/h/cut:false).
- `GET /shadowbox/assets.json` — build the palette from prop `index.json` (cut:true) + backdrop
  `index.json` (cut:false). Reuses `PropLibrary`; add a small `BackdropLibrary` + a shared manifest.
- Image-serving routes (`/lib/props/<name>.png`, `/lib/backdrops/<name>.png`) — libraries are outside
  `public/`, so mj reads the file and streams it. Guard against path traversal (basename only).
- Outcome: the existing editor, pointed at mj, shows real mj props in its palette.

**P2 — Editor port.** `sbedit.html` → `src/views/shadowbox.ecr` + `public/js/shadowbox.js` (ESM,
import from `/vendor/three.module.js`). Palette fetches `/shadowbox/assets.json`. Keep drag / scale /
depth-wheel / camera-box / horizon / floor / walk-through verbatim — that core is already generic.
De-pirate: drop the hardcoded training-room default; "ship breathing" sway becomes a generic optional
`ambientSway` scene param.

**P3 — Scenes library (persistence).** `SceneLibrary` (filesystem, `Config.scenes_dir`, same
precedence as props: `$MJ_SCENES_DIR` → config.yml → `$XDG_DATA_HOME/mj/scenes`). Routes: list, GET,
PUT (save), DELETE. Editor Save/Load hit these instead of browser file download; add a scene list +
"New/Open/Save" UI. Scenes carry provenance in an `index.json` like props.

**P4 — Player (drift) + embed.** Port `index.html` drift/parallax loop → `public/js/shadowbox-player.js`,
scene-driven (loads a scene by name, no hardcoded layers). `GET /shadowbox/play/<name>` renders a
chrome-less player view — the embeddable deliverable (drop into a game, or the siliconcircus site).
Editor's walk-through mode already exists; both modes now read the same scene.

**P5 — Generalization polish / integration.**
- Populate the backdrop library from `base`/`strip` outputs (a small import step or `mj backdrop`).
- Optional: `prop.png → webp` optimization on serve; a `scene` bus tool; `mj scene <name>` CLI.
- Notes + memory updated; `notes/shadowbox-plan.md` becomes `shadowbox-v1.md`.

## Decisions (resolved 2026-08-05)

1. **Backdrop source** → a **new backdrop library** parallel to props (same pattern, portable,
   TransFS-ready). ✔
2. **Image format** → serve `prop.png` directly now (Three loads PNG fine); **`.webp` is a wanted
   later option** (real disk savings) — a P5 lever, not dropped. ✔
3. **siliconcircus relationship** → mj's is the generalized successor; other programs (incl. the
   pirateship instance) can **copy the player + scene format** and adapt. The JSON + assets are the
   primary artifact; open `meta` fields support their custom data. ✔
4. **Naming** → **"Shadowbox"** for now (slug `shadowbox`), but "Diorama" still under debate — so the
   name is centralized (`MJ::Shadowbox::SLUG`/`TITLE`), never hardcoded, for a cheap rename. ✔

## Risks / notes

- three.js r170 is 1.3M vendored — fine for a local studio; it's the only heavy dep.
- Path-safety on the `/lib/...` and scene routes (basename-only, no `..`).
- Backdrops need real pixel dims in the manifest (read PNG IHDR at index time), like props already do.
- The editor assumes same-origin asset URLs; keeping everything mj-served (no external hosts) keeps it
  simple and CSP-clean.
