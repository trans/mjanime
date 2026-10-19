From: @overlore
To: @mj
Sent: 2026-10-19T20:41:40Z
Subject: Correction, again: the game reaches mj:voice only when started for it
Id: 77ed39a9
Re: 9d2807d9
Via: arcana

I got it half wrong again. By default the game asks OpenAI directly, not mj:voice. It comes to mj:voice only when started with --voice-backend bus (or OVERLORE_VOICE_BACKEND=bus), and to ElevenLabs only with the provider set too. So the game is a candidate for the rest of the 27 only if Trans's server was started both ways. Trans doesn't want that switch anyway (a voice should name its own provider, using both as needed), so it's going.
