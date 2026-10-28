Sent: 2026-10-28T02:51:17Z via arcana
Id: fd7a4fd2

Trans and a visitor hit three problems on overlore.xyz tonight, and Trans asked me to work them out for you. I reproduced the first and third in headless Chromium at 1280x720 and could only approximate the second. Times are from the click.

**1. After "Roll again.", the new Bard runs off and stays off screen.**
- Roll 1: the pitch act came up. The pitch Bard stayed off screen through to the email ask and never came back.
- Roll 2: the stand-up act came up. What `.bard-figure`'s computed transform did:
  - 8.4 s: none. The new Bard is in place.
  - 9.2 to 9.7 s: he hops up 60 px, then slides left to `matrix(1, 0, 0, 1, -1280, -60.48)`, one viewport width.
  - 10.2 to 11.5 s: he walks in from the right, from +960 back to 0.
  - 13.0 s: he snaps straight back to `(-1280, -60.48)` and stays there while he talks.
- At that point the element had an empty `style` attribute and `getAnimations()` returned nothing. Body classes: `top landed risen entered back may-roll`.
- The visitor saw the same: the Bard vanished just after he started talking. For them he came back at the email ask. I didn't check what brought him back.

**2. No sound, and the dialogue rolled past fast** (Trans's visit, browser and device not known yet).
- The audio serves fine: `voice/song.mp3` and `voice/greet-announcer.mp3` come back 200/206 as `audio/mpeg`, and in Chromium they play with the text kept in step.
- To mimic a browser that only lets sound start inside a tap, I made every `play()` outside a click reject with `NotAllowedError`. The page then lost the dice roll, the bubbles, `greet-announcer` (tried twice) and `song` to rejections.
- With the voice refused, the text typed itself at about 33 characters a second, roughly twice speaking pace. Nothing on the page said the sound was off.
- `localStorage` only holds `overlore_acts_seen`, so no saved mute setting was involved.

**3. Scrolling down against the end makes the Bard shake.**
- At the act's end, the page stopped scrolling at 664, 280 px further than where it started (384). The document is 1767 tall, so the browser's own limit would be 1047.
- Each wheel notch (deltaY 120, not prevented) scrolls to 784, and the page puts it back to 664 in the scroll event right after.
- The Bard moves with the page, so every notch jumps him 120 px up and back down (his top goes 87, -33, 87). A trackpad's stream of small deltas makes that a constant shake.

— @mj
