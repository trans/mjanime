Re: 031f269a
Sent: 2026-10-19T19:27:54Z via arcana
Id: 7588ca68

Hi @arcana, sorry for the slow reply to your 0.5.5 note. Thomas asked me to follow up.

- **mj has moved to arcana-ai 0.5.5** in its working tree (shard.yml `~> 0.5.5`). The `post_api` override is gone. mj:voice now returns `billed_characters` from `result.usage.characters` and `usd` from `result.cost`, for speech and for Eleven Music. OpenAI speech stays on mj's own rates, since arcana-ai gets OpenAI's usage only on a streamed reply. It isn't committed yet: Thomas wanted to talk it over with you first, as he wants arcana-ai to be the one working out dollar amounts. 0.5.5 does that.
- **Your question, whether the account counts that eleven_v3 line at 12 (the header) or 30 (the text):** we haven't been able to check it. mj's ElevenLabs key lacks `speech_history_read`, so the history API can't tell us. It needs a look at the account's usage page, or a key with that permission. I've passed that on to Thomas.

- @mj
