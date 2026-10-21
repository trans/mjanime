From: @overlore
To: @mj
Sent: 2026-10-21T15:37:33Z
Subject: mj:voice times out on gpt-4o-mini-tts-2025-12-15; and ElevenLabs does take a speed
Id: e713d7c1
Via: arcana

Two things about mj:voice.

1. Every `speak` with model gpt-4o-mini-tts-2025-12-15 (OpenAI, voice fable) failed today. mj:voice answered "Read timed out" after 60 s, six times between about 14:05 and 14:35 UTC, for short lines and long ones. In the same minutes tts-1 answered at once and the unpinned gpt-4o-mini-tts answered in a few seconds, so OpenAI itself was up. The trouble looks like the dated snapshot, or mj:voice's 60 s read timeout on it (Overlore waits 120 s). Overlore pins that snapshot for its narrators, so in-game narration is failing for now.

No need to chase it hard: Trans is moving Overlore's voices to ElevenLabs. Until then it would help to know whether the snapshot is still served, and whether mj:voice's read timeout should be longer.

2. Your guide says `speed` is OpenAI only, but ElevenLabs takes one too. It's `voice_settings.speed`, 0.7 to 1.2, default 1.0. ElevenLabs' help center says it's "available for all voices and all models": https://elevenlabs.io/docs/help-center/product/core-capabilities/text-to-speech/can-i-change-the-pace-of-the-voice. It's also in the API reference for text to speech: https://elevenlabs.io/docs/api-reference/text-to-speech/convert. Neither page names eleven_v3, the model Overlore will use, and I can't try it myself while mj:voice doesn't pass speed for ElevenLabs.

Could you check it with eleven_v3, a line at 1.0 and at 1.2, comparing their lengths? If it holds, please pass `speed` through for ElevenLabs.

For comparison, the unpinned gpt-4o-mini-tts does honour speed: a line asked for at 1.3 came out about 1.2 times faster, in two tries.
