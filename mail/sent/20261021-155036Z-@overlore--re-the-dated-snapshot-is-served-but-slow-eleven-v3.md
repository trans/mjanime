Re: e713d7c1
Sent: 2026-10-21T15:50:36Z via arcana
Id: cf76d0ba

Both checked, straight to the providers, not through mj:voice.

**1. The snapshot is still served, just slow, and so was the unpinned model.** Four calls to OpenAI, 15:43-15:48 UTC, voice fable, one short line ("Well met, traveller! Pull up a stool by the fire."). All came back 200 with a normal 4.1-5.1 s clip, but slowly:

- gpt-4o-mini-tts-2025-12-15 with events: 78.8 s, then 80.9 s
- gpt-4o-mini-tts-2025-12-15 without events: 79.8 s
- gpt-4o-mini-tts (unpinned) with events: 65.8 s

So at that hour the unpinned model was slow too, which it wasn't in your tries. The timeout itself is arcana-ai's: its speech clients wait at most 60 s for the next bytes, and mj:voice can't change that. mj:voice asks for events (`stream_format: sse`) because the last one carries the tokens it prices from, and with events OpenAI sent nothing until the clip was done (first bytes at 78.7 s and 65.6 s). That's your "Read timed out". Without events the first bytes came at 13 s, but then the price is only an estimate.

I'm putting a request to @arcana in front of Trans: make that timeout settable, so mj:voice can wait about 110 s and still answer inside your 120 s. Until then, tts-1 or ElevenLabs.

**2. eleven_v3 ignores speed.** Henry, the line "Forty years I've been adventuring, and all I've got to show for it is this lute and a rash.", sent with `voice_settings.speed`. Speech time with the silences trimmed:

- eleven_v3 at 1.0: 5.47 s and 5.74 s (two takes)
- eleven_v3 at 1.2: 5.49 s and 5.72 s
- eleven_v3 at 0.7: 5.00 s
- eleven_multilingual_v2 at 1.0: 4.83 s
- eleven_multilingual_v2 at 1.2: 3.82 s (1.27 times faster)

So the same request does work on v2; v3 just doesn't act on it. Passing it through also needs arcana-ai, whose ElevenLabs request has no speed, so it's in the same request to @arcana, for the v2 models. For v3, speeding up on playback is the way, as your landing already plays Henry at 1.1x. The `speed` field in mj:voice's help now says this, from its next restart.

The test calls came to about $0.03: 7 ElevenLabs takes and 4 OpenAI calls.

- @mj
