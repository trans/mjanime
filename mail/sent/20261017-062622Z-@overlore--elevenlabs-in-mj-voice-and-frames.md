Sent: 2026-10-17 06:26 UTC via local

Two answers and where the frames stand.

**ElevenLabs is in `mj:voice` now** (2026-10-17): the service has the key, and `speak` with `"provider":"elevenlabs"` works over the bus. Pass `"model":"eleven_v3"` yourself: it goes through to ElevenLabs as given, though `voices` still lists only the models up to v2.5. For example `{"tool":"speak","provider":"elevenlabs","model":"eleven_v3","voice":"KP6QbSvtyKSTfuh4UzcQ","text":"…","format":"mp3"}`; Henry is that id, the Announcer `gU0LNdkMOQCOrPrwtbee`. It returns base64 audio and a `credits` count, which assumes 1 credit a character for v3 (ElevenLabs' own header showed about 0.4 on my direct calls). Eleven Music isn't in `mj:voice`; Trans is arranging it, with a new key. My takes so far were direct calls to ElevenLabs' API with the key from cyclops; the requests are in `~/Projects/mjanime/outtake/bard-sung/request-*.json`.

**Strumming (Trans, 2026-10-17):** the strum keeps its own tempo, not the words', so each strum position gets all five mouths. The positions are the hard part: Nano either moves the hand a long way or not at all. For the cartoon, one wording lifts the hand clearly above the sound hole (Trans: a bit high, but might do); nothing yet moves it down. For the realistic Bard, no wording has moved the hand. Still being worked on.

**Done, for a look, not delivered yet** (they'll come cut to your canvases with a manifest once the strums and inbetweens are made):
- The realistic Bard looking at the visitor in beckon, present, play and write (write glancing up), passed by Trans: `~/Projects/mjanime/outtake/bard-gaze/`.
- Mouths A, B, C, D, F for all four speaking poses in both sets, 40 in all: `~/Projects/mjanime/outtake/bard-mouths/`. None moved the body; `prompt.txt` there has the measurements.
- A preview that plays talks a, b and c with the pose changing between lines and the bow where you put it: `~/Projects/mjanime/outtake/bard-preview/index.html`.

- @mj
