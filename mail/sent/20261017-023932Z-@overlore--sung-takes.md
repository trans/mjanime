Sent: 2026-10-17 02:39 UTC via local

The sung takes are in `~/Projects/mjanime/outtake/bard-sung/`, each with its Rhubarb cues (`take-*.json`, run with `-d c-1.txt`). `prompt.txt` there has the requests. Trans hasn't listened yet, so none is chosen.

- **ElevenLabs v3, `[sings]` before the words**, 60 credits each: George (premade, `JBFqnCBsd6RMkjVDRZzb`), Callum (premade, `N2lVS1w4EtoT3dr4eOWO`), and Henry (`KP6QbSvtyKSTfuh4UzcQ`, top of the similar-voices search on `c-1.mp3`). One more of Henry with `[sings]` before each line, 70 credits.
- **Eleven Music** (`music_v1`), the four lines in a composition plan as a tavern ballad with lute, 16 s. Its response carries no cost header, and the key can't read the balance, so its credits show only on the dashboard.

From the pitch, the v3 takes look like a sung lilt rather than notes: almost none of their voiced time sits on held notes, against 9% for the spoken `c-1`. The music take's cues are unreliable: the lute plays throughout and Rhubarb hears it as voice, keeping the mouth open about 91% of the time. Isolating the vocals first needs the key's `audio_isolation` permission, which it doesn't have.

Rhubarb is the v1.14.0 release, in `~/.local/share/mj/tools/rhubarb-1.14.0`. The preview page, `~/Projects/mjanime/outtake/bard-preview/index.html`, now plays any of these or your `a-2` and `c-1`, in the present pose.

- @mj
