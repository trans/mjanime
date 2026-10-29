# `mj listen`: checks on a voice take

mj can't hear, so before a take reaches Thomas this command checks what can be checked without ears. It
measures glitches, compares the words with the script through two listeners, guesses the accent and,
given a reference, says whether the take sounds processed. It reports; Thomas still judges.

```
mj listen <take>... [--script TEXT] [--ref REF] [--free | --glitches] [--json]
```

- **The script:** `--script` gives one for every take. Otherwise each take uses the `.txt` beside it
  with the same name, as outtake `landing-tour/` keeps them. Audio tags (`[strong Scottish accent]`,
  `[chuckles]`) are taken out before comparing.
- **Options:**
  - `--ref` compares each take with a reference take.
  - `--free` skips Gemini; the glitch checks and Whisper still run.
  - `--glitches` runs the glitch checks alone.
  - `--json` prints the results as JSON.
- **Needs:** `ffmpeg`. Whisper runs through `uv` (`uv run --with faster-whisper`, model `small.en`
  from the Hugging Face cache). Gemini needs `GEMINI_API_KEY`
  (`eval "$(cyclops-env export mj local --format bash)"`). If one is missing, that check is skipped
  with a note. Gemini is asked up to three times. It now and then answers with nothing, and a take
  that never gets an answer is checked by Whisper alone, with a note, so the other takes still report.
- **Cost:** a take's words and accent are one Gemini 3.8 Flash call, about $0.0007. A comparison with
  a reference is one Gemini 3.1 Pro call, about $0.004. Both go into the spend log as `cmd: listen`.
  The glitch checks and Whisper are free.

## Why it's built this way

It comes out of the listen test (outtake `listen-test/README.md`, 2026-10-29). That test asked Gemini
about 28 clips whose answers were known: planted faults, and Thomas's past calls.

- **Glitches are measured, not asked.** Gemini found 2 of 8 planted clicks, cuts, dropouts and clipped
  stretches, and a different two when it thought harder. The measurements below find 7 of the 8 and
  nothing in mj's 339 real voice takes.
- **Words go to two listeners.**
  - On the Scottish tour takes, Whisper misheard u-2 and u-9 (for example "roar the dice") where
    Gemini heard the script.
  - Both heard u-4's "Like a hotel" as "What's a hotel".
  - So a difference both listeners hear is marked *worth a listen*. A difference only one hears is
    more likely that listener's mistake.
- **Processing is only judged against a reference.** Given a take alone, neither model heard any
  pitch shift. Given Henry's original, Gemini 3.1 Pro called the shifted Henrys processed in the
  test.
  - A later run missed the +1 semitone one, so read it as catching clear processing (+3 semitones,
    1.1x speed), not slight shifts.
  - It mixes up pitch and pace, so only its yes or no and its note are shown.
- **Not offered: whether two takes are the same speaker.** Both models called the Announcer and Gerald
  the same person.
- **The accent is a guess.**
  - Gemini 3.8 Flash was right about Scottish or not on 10 of 11 test clips.
  - It then called plain Gerald's tour line 4 Scottish, though it had called his line 1 English.

The prompts are the test's own, word for word, since they're what was measured. Only the answers the
test found trustworthy are read from them.

## The glitch checks

`MJ::Listen::Glitch`, in Crystal, on the take decoded to 24 kHz mono. Each threshold sits between the
strongest value in mj's real takes and the weakest planted fault (outtake `listen-test/glitch/`):

| finds | how | real takes, at most | planted |
| --- | --- | --- | --- |
| a click | a 1–3 ms burst, 25x as bright as its 50 ms surroundings, with a sample-to-sample step of 1.0 or more | step 0.81 | 1.45 |
| a hard cut | one step of 0.7 or more, 10x the steps round it | 0.58 | 0.86 |
| a dropout | 20 ms or more of digital silence inside the take, which the voice falls into from full volume (RMS 0.1 over the 10 ms before) | 0.063 | 0.28 |
| clipping | 20 or more flat tops (4+ equal samples above 0.2) within 50 ms of each other | 5 | 61 to 363 |

- **Absolute thresholds:** they aren't scaled to the take. They were set on ElevenLabs takes peaking
  near -1 dBFS, so a much quieter take is checked less sensitively.
- **A clipped stretch's edges:** they are big steps too, so a cut inside one is reported as the
  clipping.
- **What they miss:**
  - a cut that lands where the waveform meets itself (one of the two planted cuts);
  - a glitch that's a sound in its own right, such as a garbled syllable;
  - a voice starting at full volume after a silence, which isn't counted: two of the Kokoro voice
    tests do that.

## Output

```
tour-u-4-gerald-scottish.mp3 (6.64 s)
  glitches: none found (clicks, hard cuts, dropouts, clipping)
  words, against tour-u-4-gerald-scottish.txt (Whisper and Gemini):
    "Like" at 3.3 s: Whisper heard "What's", Gemini heard "what's" (both: worth a listen)
    "room's": Gemini heard "room is" (only Gemini)
  accent (Gemini): Scottish; Scottish throughout: yes
```

The times come from Whisper's word timings. A take without a script shows what Gemini heard. With
`--ref`, a last line gives Gemini 3.1 Pro's "processed" answer and its note.

`spec/listen_spec.cr` covers the measurements on synthetic tones, and the word comparison.
