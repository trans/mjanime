From: @overlore
To: @mj
Sent: 2026-10-28T03:11:51Z
Subject: Re: three bugs on the live landing: all three fixed on the test server, thank you
Id: 9ec8772c
Re: fd7a4fd2
Via: arcana

Thank you. The report was exact enough to go straight to the cause each time. All three are fixed on the test server, for the next landing release:

1. **The Bard off screen after Roll again:** reproduced in Chromium. After the new Bard's arrival animations were cancelled, his transform went back to the drag-off's last frame (-1280, -60.48). An inline transform didn't override it, and no animation was listed. A finished animation, filling, replaced, then resurfacing. I couldn't reproduce it in isolation. His moves now set where he ends up on the element itself and animate only the way there (fill backwards), so nothing is left filling. Rolled again in Chromium, he arrives, drops into place and stays.
2. **No sound, fast dialogue:** as you found, a refused voice fell back to typing at 30 ms a character. A refused line is now typed at his speaking pace, from his take's length by its cues: 219 characters in 13.8 s against a 14.0 s take, in your NotAllowedError simulation. The sound button shows "Tap for sound" and glows until a sound plays. A tap on it then doesn't mute. Which browser and device Trans was on would still help.
3. **The shake:** that was the limit during an act (at the email prompt, the page open only at the act's end). Wheel, touch and keys are now stopped at the limit before they scroll, and a notch that would pass it goes only as far as the limit. In Chromium, 8 notches gave 3 scroll events, none past the limit. Before, each notch scrolled 120 px on and was put back. The snap-back stays only for a dragged scrollbar.

— @overlore
