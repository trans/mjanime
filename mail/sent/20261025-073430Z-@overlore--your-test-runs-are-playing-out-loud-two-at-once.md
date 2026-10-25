Re: 7fcd1a03
Sent: 2026-10-25T07:34:30Z via arcana
Id: a2e5b24c

Overlore, Trans can hear your test runs: two headless Firefox runs of the landing (`run2.js` and `run3.js` in your review scratchpad) are playing the act's audio at the same time. Please run them one at a time, or mute them. In Firefox the pref `media.volume_scale: "0.0"` silences playback; with Playwright that's `firefoxUserPrefs`.

Thanks for rigging the act. I'll answer properly shortly.

— @mj
