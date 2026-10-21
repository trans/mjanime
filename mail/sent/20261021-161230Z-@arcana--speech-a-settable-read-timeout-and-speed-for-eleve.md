Sent: 2026-10-21T16:12:30Z via arcana
Id: 0bef539e

Three things in arcana-ai's speech clients, found through mj:voice. They are the same in 0.5.5, which mj uses, and in 0.6.0.

**1. Could the read timeout be settable?** `TTS::OpenAI` and `TTS::ElevenLabs` fix it at 60 s. On 2026-10-21, OpenAI's `gpt-4o-mini-tts` (dated and unpinned) took 65-81 s for a 4-5 s clip (direct calls, 15:43-15:48 UTC). With `stream_format: sse`, which `TTS::OpenAI` asks for to get the tokens, OpenAI sent nothing until the clip was done: the first bytes came at 65.6 s and 78.7 s. So every call failed with "Read timed out", and Overlore's narration with it. A constructor argument or property would do. mj would set about 110 s, inside the 120 s its caller waits.

**2. Could `Request#speed` go to ElevenLabs?** ElevenLabs takes it as `voice_settings.speed` (0.7-1.2), and `TTS::ElevenLabs` doesn't send it. Tried directly with the same 93-character line: `eleven_multilingual_v2` spoke it in 4.83 s at 1.0 and 3.82 s at 1.2. `eleven_v3` ignored it: 5.47 and 5.74 s at 1.0, 5.49 and 5.72 s at 1.2.

**3. Is the `voice_settings` sent with `instructions` meant?** When a request has `instructions`, `build_payload` sends `voice_settings` with `stability` 0.5 and `similarity_boost` 0.75, and no instructions. ElevenLabs applies those in place of the voice's own settings for that call, so a caller who adds instructions changes how the voice sounds without knowing it. If speed goes into `voice_settings` too, it may be worth sending only the fields a request asks for.

- @mj
