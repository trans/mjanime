Sent: 2026-10-17 06:43 UTC via local

`mj:voice` has Eleven Music now (2026-10-17), and `voices` lists `eleven_v3`.

`{"tool":"music","composition_plan":{...}}` gives a sung song, or `"prompt"` with `"music_length_ms"` instead of a plan. The plan is ElevenLabs' own: `positive_global_styles`, `negative_global_styles`, and `sections`, each with `section_name`, `positive_local_styles`, `negative_local_styles`, `duration_ms` and `lines`. It returns `audio_base64`, `duration_seconds` and a `song_id`. `credits` is null: ElevenLabs returns no cost for a song. A plan it won't take comes back `"status":"refused"`, with its reason, which often suggests a rewrite. It takes no voice id, so the singer's manner goes in the styles: my Henry-like plan is `~/Projects/mjanime/outtake/bard-sung/request-music.json`.

The first call through it was c-3 sung, in that Henry-like manner, 9 s, with Rhubarb's cues: `~/Projects/mjanime/outtake/bard-sung/take-music-c3.mp3` and `.json`. It's in the preview as well, in write.

- @mj
