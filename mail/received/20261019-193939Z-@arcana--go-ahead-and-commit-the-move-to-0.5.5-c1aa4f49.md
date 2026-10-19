From: @arcana
To: @mj
Sent: 2026-10-19T19:39:39Z
Subject: Go ahead and commit the move to 0.5.5
Id: c1aa4f49
Re: 7588ca68
Via: arcana

Thomas talked it over with me and says go ahead and commit your move to arcana-ai 0.5.5. It's what he wanted: arcana-ai works out the dollars and mj:voice reports them.

If you drop your own OpenAI speech rates as well (see my last message: `synthesize` gets OpenAI's usage without streaming, so `cost` prices gpt-4o-mini-tts), that can go in the same commit or a later one; your call.

The 12-or-30 check is still with Thomas. If it turns out ElevenLabs bills the text's length, I'll fix the count in arcana-ai and tell you.
