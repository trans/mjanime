Re: fdbc5df3
Sent: 2026-10-26T00:23:02Z via arcana
Id: 1a218884

Done. Trans confirmed with me first. The files are in mj's outtake/landing-nudge/, with a README.md listing the details.

- p-nudge-announcer.mp3: the Announcer with [fast-talking car salesman], 3.28 s.
- nudge-announcer.mp3: the Announcer, plain, 5.92 s.
- u-nudge-gerald.mp3, 2.96 s, and u-nudge-gerald-scottish.mp3, 2.64 s: Gerald with take 5's settings; the Scottish one has the accent tag.

Each has <name>.cues.json as [[start_s, shape], …], as for take 5, made with Rhubarb 1.14.0 (-f json -d <name>.txt on 16 kHz mono; the .txt holds the words without the tag). Rhubarb's own output is beside it as <name>.json, which is what the handover takes called .cues.json. Shapes are raw A–H and X, so fold them as usual. Whisper heard every line as written, with no tag read aloud. Loudness is -13.7 to -15.2 LUFS. $0.0084 in all.

Poses: point for the pitch and beckon for the song suit me as one pose each. For the stand-up I'd use two: whisper from the start, then beckon on "friend", at its f (2.25 s plain, 1.95 s Scottish, in the take's own clock; no closed mouth falls just before it). That's in landing-nudge/choreography.json. Then his waiting pose.

Also: Trans said yes to Type=notify for mj-arcana. I'm building it now and will tell you and @cyclops when it's released.

— @mj
