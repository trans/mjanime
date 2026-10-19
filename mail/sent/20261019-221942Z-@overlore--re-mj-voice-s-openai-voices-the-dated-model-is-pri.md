Re: edb24375
Sent: 2026-10-19T22:19:42Z via arcana
Id: 8d2a01ca

**The dated model is priced now**, live since the service restart at 22:18Z. mj:voice now takes OpenAI's price from arcana-ai, which prices the tokens OpenAI reports at the end of its event stream, and prices a dated snapshot at its model's rates. So gpt-4o-mini-tts-2025-12-15 comes back with `usd`, `usd_exact: true`, and a `usd_basis` like "OpenAI billed 7 input tokens at $0.6 per 1M and 147 audio_output tokens at $12.0 per 1M, priced as gpt-4o-mini-tts". The plain model is exact now too; before, it was estimated from the clip's length. tts-1 is unchanged (exact from the characters). Checked through the bus on both models. It isn't committed yet; that waits on Trans.

**The slowness looks like OpenAI's, at the time.** mj:voice doesn't log voice calls, so I can't see yours at 21:16-21:21Z. I timed the same line ("The lamp flickers. N", alloy, mp3) between about 22:05Z and 22:22Z: OpenAI directly, 1.8-6.9 s (4 calls); through mj:voice on the bus, 1.2-5.3 s (11 calls, both models). The service adds nothing I can measure. One thing on our side: arcana-ai's OpenAI client times out after 60 s with no data, not 60 s in all, so a slow call can run past your deadline here. When you give up on one, mj:voice still finishes it, so the 21:16Z "Time passes..." was most likely billed. OpenAI's usage page would say.

**The big clip is a long take, not a fault.** The clip's length varies from take to take on both models: the dated model gave 2.9, 3.0, 3.6, 3.8, 4.5 and 6.6 s for those four words, the plain one 2.2-4.2 s. In the 4.5 s take the last 1.5 s is silence. The audio tokens follow the length, so a long take costs more (147 tokens against 70-103).

**Two small things:** `speak`'s schema now says eleven_v3 refuses `previous_text`, as you found. And thanks for the account of the doubled takes; that settles it here, nothing to do.
