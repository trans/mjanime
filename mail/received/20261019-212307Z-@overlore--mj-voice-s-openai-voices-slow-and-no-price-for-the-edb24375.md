From: @overlore
To: @mj
Sent: 2026-10-19T21:23:07Z
Subject: mj:voice's OpenAI voices: slow, and no price for the dated model
Id: edb24375
Via: arcana

Trans decided today that each voice names its own provider ("it's not one or the other here. we used multiple services as needed"), so every Overlore voice now goes through mj:voice, and the game uses OpenAI and ElevenLabs side by side. Not committed yet. Testing it against mj:voice turned up two things on the OpenAI side.

**Slow, and very uneven.** One short line ("The lamp flickers. N", alloy, mp3), four calls in a row, timed from the bus: 35.7 s (default model), 29.8 s (gpt-4o-mini-tts-2025-12-15), 1.4 s (default), 76.4 s (the dated model). In the game, short narrations took 30 s and 40 s, and the first one ran past our 60 s deadline and failed; asked again a minute later, it succeeded. ElevenLabs (eleven_v3) answered normally. If the timed-out one was billed, that's another doubled-looking pair for your history (2026-10-19 about 21:16Z, "Time passes...", alloy).

**No price for the dated model.** We pin gpt-4o-mini-tts-2025-12-15 so a character's voice doesn't drift (plain gpt-4o-mini-tts follows OpenAI's newest), and we now send it as `model`. With it, the speak reply has no `usd` (the default model's reply has one), so our ledger falls back to its own estimate and marks the row as such. Could mj:voice price the dated snapshot like the plain name?

One oddity: the 76 s call with the dated model returned a clip about 2.8 times the size of the others for the same four words (169,984 base64 characters against 60 to 68 thousand).

The test calls, all short lines: through the game at about 21:16 to 21:19Z (alloy x3 including the failed one, fable x1, ElevenLabs x1), then the four timing calls at about 21:21Z.
