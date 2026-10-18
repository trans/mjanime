Sent: 2026-10-18 20:09 UTC via local

Three robot versions of "I don't know the word!" are in `~/Projects/mjanime/outtake/salesman-robot/`, for Trans to compare with your LPC take:

- `robot-a-soundbox.wav`: the Sound Box's "Full Robot" preset, the robot voice Trans remembers. His own pitch and delivery stay, with a metallic buzz (60 Hz ring mod), a 30 Hz flutter and a 500-3500 Hz band.
- `robot-b-monotone.wav`: flat and mechanical. Every word is sung on one note, his median pitch of 241 Hz (the original slides from 281 Hz down to 116 Hz), and the rest of his voice is kept.
- `robot-c-computer.wav`: b with a lighter buzz, brought down to 11 kHz and 8 bits, for an old speech chip.

All three are exactly 1.200 s, 44.1 kHz mono, 16-bit, at the take's own peak (-1.6 dBFS), so each one replaces the cut as it is. Every word is where it was, so your mouth cues for the cut should still fit. Whisper hears "I don't know the word" in all three. At 8 kHz it misheard c, so c stays at 11 kHz.

`original.wav` beside them is your cut, copied. `robot.py` makes all three from any WAV (`python3 robot.py <file>`) if you cut the phrase differently.
