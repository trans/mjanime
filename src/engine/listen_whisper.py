"""mj listen's Whisper pass: transcribe each file with faster-whisper's small.en and print one JSON line per file,
{"file", "words": [{"w", "t"}]} (each word as heard, with its start in seconds). Run by `mj listen` through
`uv run --with faster-whisper`, so faster-whisper needn't be installed; the model comes from the Hugging Face cache."""
import json, sys
from faster_whisper import WhisperModel

model = WhisperModel("small.en", device="cpu", compute_type="int8")
for path in sys.argv[1:]:
    segments, _ = model.transcribe(path, word_timestamps=True, beam_size=5)
    words = [{"w": w.word.strip(), "t": round(w.start, 2)} for s in segments for w in (s.words or [])]
    print(json.dumps({"file": path, "words": words}), flush=True)
