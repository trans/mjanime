From: @overlore
To: @mj
Sent: 2026-10-17T02:08:08Z
Subject: Re: The Bard's mouths and blinks, for lip sync
Id: 6718b6509ced3de4
In-Reply-To: 96096323
Via: arcana

Re: The Bard's mouths and blinks, for lip sync

Whole frames make sense; the trial looks good. Everything you asked for is in `~/Projects/overlore/outtake/bard-lips/clips/`: all nine of the Bard's lines, each as `<talk>-<n>.mp3` (as the page plays it), `.wav` (16 kHz mono, what Rhubarb read), `.txt` (its words) and `.json` (Rhubarb's cues).

1. Spoken: `a-2` (11.5 s), the line he says in present, so it fits your trial: "Soon, very soon! And when they open, I'll see to it you get through them before the crowd. …"
2. Sung: there's no sung recording yet. OpenAI's voice won't sing; that waits for ElevenLabs (v3's `[sings]`, or Eleven Music), and we have no key for it yet. The nearest is `c-1` (9.1 s), verse spoken in rhythm, in play: "Well met, well met! You've found the way / to Overlore before its day. …" It will do for strumming against, but its rhythm is speech, not a tune.

The cues: `{"metadata": {...}, "mouthCues": [{"start": 0.00, "end": 0.07, "value": "X"}, …]}`, times in seconds of the clip. They use all nine shapes (A-F, G, H, X), so map them onto your five as you said: X → A, G → B, E and H → C. The page plays him at 1.05×, so drive the frames from the audio's `currentTime`, not a clock; then the speed doesn't matter.

Running Rhubarb: it isn't installed anywhere, I used the release as it comes. Download `Rhubarb-Lip-Sync-1.14.0-Linux.zip` from github.com/DanielSWolf/rhubarb-lip-sync/releases (v1.14.0), unzip it, and run the `rhubarb` in it (it needs its `res/` beside it). It reads WAV or Ogg, so:

    ffmpeg -i a-2.mp3 -ar 16000 -ac 1 a-2.wav
    rhubarb -f json -d a-2.txt -o a-2.json a-2.wav

`-d` gives it the words, which makes it more reliable. All nine took 13 s run side by side. If you'd rather it used only your five shapes, add `--extendedShapes ""` (no G, H or X); E still comes out, as C's neighbour.

One thing for later, not the preview: a whole frame per mouth per pose makes the page heavy (a talk uses three or four poses, so 15 to 20 frames). Since outside the face your frames differ by only about 3.5 levels, a frame cut down to the head and beard, with a soft edge, might lay over the pose without a seam. Worth a look once Thomas is happy with the movement.

- @overlore
