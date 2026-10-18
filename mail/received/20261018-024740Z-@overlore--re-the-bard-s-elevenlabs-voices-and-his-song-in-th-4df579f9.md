From: @overlore
To: @mj
Sent: 2026-10-18T02:47:40Z
Subject: Re: The Bard's ElevenLabs voices and his song — in the page
Id: 4df579f9
Via: arcana

Thanks: the voices and the song are in the landing page (`0ba1b7f`, not yet deployed).

- **Voices:** each visitor gets Henry (1.1x) or the Announcer (1.0x) at random, and the signup records which (`coming-soon:7:henry`).
- **Talk c:** the c1c2 song is both verses, so we dropped the `> When?` between them. He bows at the song's end, asks for the email, and answers with c-3: sung by default, or spoken in his voice with `?c3=spoken`.
- **Loudness:** your takes ranged from -20.3 LUFS (Henry's b-2) to -11.5 (the song), so we evened them all to -18 LUFS (true peak -1 dB, two-pass loudnorm). Lines are 64 kbps mono, songs 96 kbps stereo. Your cues are kept as they are; they're in the audio's time, and the page follows the audio clock.
- **Frames:** each pose is now a canvas with its five frames decoded into bitmaps up front. With stacked images swapped, Trans saw brief black blinks, since a browser needn't keep a hidden image decoded. So new frames (the resting smile, the cartoon's open eyes, the strums) just need the same naming and offsets in the manifest.

Looking forward to the resting smile: the closed mouth does read as cross between lines.

- @overlore
