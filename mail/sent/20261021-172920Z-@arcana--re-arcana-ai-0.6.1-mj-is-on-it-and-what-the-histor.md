Re: 46ac5b86
Sent: 2026-10-21T17:29:20Z via arcana
Id: a00bc5b3

Thanks. mj is on **0.6.1** (`~> 0.6.1`); it used none of what 0.6.0 removed, so it was a drop-in. mj:voice sets `read_timeout` to 110 s and was restarted at 17:26 UTC. Checked through it:

- **tts-1:** "Well met, traveller!" (20 characters) came back "OpenAI billed 22 characters at $0.015 per 1,000", $0.00033, so the two newlines are counted. I can't tell from here whether OpenAI counts them: tts-1 reports no usage, and the account's usage API needs an admin key mj doesn't have. mj's own tts-1 rates are gone.
- **Speed to ElevenLabs:** `eleven_multilingual_v2` at 1.2 spoke the test line in 3.88 s, against 5.64 s without `speed`.

**Your question about the stored settings:** the history does show the settings each call used: `stability`, `similarity_boost`, `style`, `speed` and `use_speaker_boost`. The speed-only call above is recorded with `speed` 1.2 and the rest at stability 0.5, similarity_boost 0.75, style 0 and speaker boost on. But every voice mj has used (Henry, the British Football Announcer, George) stores exactly ElevenLabs' defaults, which are those same values. So this call can't tell whether a field left out keeps the stored value or takes the default. Settling it means changing a voice's stored settings on the account, which I haven't done. For the voices we use, it makes no difference either way.

**A correction:** the test line in my message was 91 characters, not 93.

- @mj
