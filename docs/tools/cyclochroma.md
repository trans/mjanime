# Cyclochroma — key a colour out, light the hole up with the music

A web page at **`/cyclochroma`** (`mj serve`, port 21683). Remove a chroma from an image with a soft
feathered edge, and render a music-reactive colour field through the resulting transparency. The
keyed region becomes a window; the field lives behind it.

It is a **runtime** feature, not a CLI one: music synchronisation needs live FFT, so the whole thing
runs in the browser. Nothing is uploaded and nothing is written server-side.

## Use

1. **Image** — drop a PNG/WebP. The backdrop colour is sampled from the corners automatically.
2. **The key** — adjust the ramp; pick a different colour with the eyedropper if the corners lied.
3. **Music** — drop a wav/mp3 (optional; with no track the field still cycles on its own).
4. **The effect** — pick a field, set cycle speed and audio drive, press play.

`⏺ Record WebM` captures the canvas via `MediaRecorder` and downloads it.

## The key

Mirrors the [prop keyer](prop.md) so results match what `mj prop` would produce:

| Control | Meaning |
| --- | --- |
| Clear below | distance from the key colour under which a pixel is fully transparent (`key_low`) |
| Opaque above | distance above which it is fully opaque (`key_high`) |
| Feather | px of blur on the alpha edge |
| Fade curve | gamma on the ramp — under 100% hardens the transition, over 100% softens it |
| Despill | strips the key hue from partially-transparent edge pixels |

**The backdrop is sampled on load, not taken from the swatch.** This matters: a Nano render's
"magenta" is never exactly `#ff00ff`. The basalt cave render measured `rgb(254, 43, 251)` — distance
42 from pure magenta, which with a default 10..70 ramp leaves the whole background sitting at ~53%
alpha instead of clear. Same reason `prop.yml` sets `auto_background: true`.

## Holes only

Off, the field fills every transparent pixel. On, it fills only **enclosed** openings — the space
around the subject stays transparent (a prop still has to composite into a scene), it just isn't lit.

Implemented by flood-filling from the border, the same idea as [matte](matte.md) Tier 1. The flood
passes through anything **not fully opaque**, not merely through clear pixels: a feathered silhouette
has a partial-alpha fringe, and treating that fringe as "window" lights it as a halo around the
subject.

## Fields

| Mode | What it does |
| --- | --- |
| Cycle | one hue filling the window, rotating; bass pushes the hue, level pushes brightness |
| Spectrum | 64 bars by frequency, hue spread across the window |
| Radial | concentric rings from the centre, pulsing on level |
| Plasma | two-stop gradient whose sweep is driven by the mids |

Audio is analysed with a 2048-point FFT split into bass (0–6%), mid (6–35%) and treble (35–100%),
plus a weighted overall level. **Cycle speed** is the time-based hue rotation; **Audio drive** is how
much the music modulates it. Set cycle speed to 0 and the field only moves when the music does —
which is also how to verify the sync is real.

---
Related: [tools index](README.md) · [prop](prop.md) · [matte](matte.md) · [sfx](sfx.md)
