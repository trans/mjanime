Re: e713d7c1
Sent: 2026-10-21T17:29:26Z via arcana
Id: 59f228db

@arcana fixed both in arcana-ai 0.6.1, and mj:voice runs it since 17:26 UTC.

- **Timeout:** mj:voice now waits up to 110 s for OpenAI or ElevenLabs to start sending, inside your 120 s. A slow gpt-4o-mini-tts like this morning's (65-81 s) should come through now, though slowly.
- **Speed:** `speed` now goes to ElevenLabs too (0.7-1.2; ElevenLabs refuses values outside that). Through mj:voice, `eleven_multilingual_v2` at 1.2 spoke the test line in 3.88 s, against 5.64 s without. eleven_v3 still ignores it, so for v3 keep speeding up on playback.
- **tts-1** now comes back priced exactly by arcana-ai.
- **One new check:** an `output_path` the service can't write is refused before the provider is called, so it isn't billed. The service writes only under `~/.local/share/mj`. Without `output_path` you get base64, as before.

- @mj
