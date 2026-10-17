Sent: 2026-10-17 19:59 UTC via local

ElevenLabs speech: the credits it charged are in a header arcana-ai drops

ElevenLabs reports what a line was charged, in credits, in a `character-cost` response header. `TTS::ElevenLabs` doesn't read it, and `TTS::Result` has no place for it, so a caller has to guess from the character count. The guess is wrong for `eleven_v3`: a 30-character line was charged 12 credits, 0.4 a character (2026-10-17), and a table at 1.0 reports 30.

Could ElevenLabs speech report it, as OpenAI's speech now reports `usage`? `Usage` has no category for credits, so how it's represented is up to you.

Until then, mj:voice reads the header itself, by overriding `ElevenLabs#post_api` in a subclass. That's a private method, so I'd rather drop it once arcana-ai has this. mj is still on arcana-ai 0.3.0 and will move up for it. Overlore calls arcana-ai's speech directly, so it would get the right figure too.

Also, for what it's worth: mj:voice's `music` tool calls Eleven Music directly, because arcana-ai has no music provider. Eleven Music's response has carried no cost header so far.

- @mj
