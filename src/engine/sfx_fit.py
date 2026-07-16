#!/usr/bin/env python3
"""Fit a procedural Web Audio SFX recipe from a reference sound.

Usage: sfx_fit.py <input.wav|mp3|...> [--preview out.wav]
Prints the recipe JSON to stdout. Every parameter is derived from the signal:
band edges + resonant peak (spectrum), noise-vs-tonal (spectral flatness),
attack/release (envelope), wobble rates/depth (envelope modulation spectrum).

Deps: python3, numpy, scipy, ffmpeg (for decoding any input to mono PCM).
"""
import sys, os, json, argparse, tempfile, subprocess
import numpy as np


def load_mono(path, fs=44100):
    tmp = tempfile.mktemp(suffix=".wav")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path,
                    "-ac", "1", "-ar", str(fs), "-c:a", "pcm_s16le", tmp], check=True)
    from scipy.io import wavfile
    sr, x = wavfile.read(tmp)
    os.remove(tmp)
    x = x.astype(float)
    return sr, x / (np.max(np.abs(x)) + 1e-9)


def biquad(kind, f0, Q, gDb, fs):
    A = 10 ** (gDb / 40); w = 2 * np.pi * f0 / fs; c = np.cos(w); s = np.sin(w); al = s / (2 * Q)
    if kind == "lowpass":   b = [(1 - c) / 2, 1 - c, (1 - c) / 2]; a = [1 + al, -2 * c, 1 - al]
    elif kind == "highpass": b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]; a = [1 + al, -2 * c, 1 - al]
    elif kind == "peaking":  b = [1 + al * A, -2 * c, 1 - al * A]; a = [1 + al / A, -2 * c, 1 - al / A]
    else: raise ValueError(kind)
    b = np.array(b) / a[0]; a = np.array(a) / a[0]
    return b, a


def render(r, fs=44100, seed=7):
    from scipy.signal import lfilter
    rng = np.random.default_rng(seed); n = int(r["duration"] * fs); t = np.arange(n) / fs
    src = r["source"]
    if src["type"] == "noise":
        x = rng.standard_normal(n)
    else:
        f0 = src.get("freq", 440); f1 = src.get("freqEnd", f0); sw = np.linspace(f0, f1, n)
        ph = 2 * np.pi * np.cumsum(sw) / fs
        x = {"sine": np.sin(ph), "square": np.sign(np.sin(ph))}.get(src.get("wave", "sine"), np.sin(ph))
    for f in r.get("filters", []):
        b, a = biquad(f["type"], f["freq"], f.get("q", 0.707), f.get("gain", 0), fs); x = lfilter(b, a, x)
    w = r.get("wobble")
    if w:
        mod = sum(np.sin(2 * np.pi * rt * t) for rt in w["rates"])
        x = x * (w.get("base", 0.7) + w.get("depth", 0.2) * mod)
    e = r.get("env", {}); at = min(int(e.get("attack", .01) * fs), n - 1)
    rl = min(int(e.get("release", .1) * fs), n - at - 1); env = np.ones(n)
    if at > 0: env[:at] = np.linspace(0, 1, at) ** 2
    if rl > 0: env[-rl:] = np.linspace(1, 0, rl) ** 1.5
    x *= env; x /= np.max(np.abs(x)) + 1e-9; x *= r.get("gain", .9)
    return fs, x


def autofit(path):
    sr, x = load_mono(path)
    win = int(0.02 * sr)
    env = np.sqrt(np.convolve(x ** 2, np.ones(win) / win, mode="same"))
    # sustained BODY = longest run above threshold, after closing the sound's own dips
    thr = 0.08 * env.max(); a = (env > thr); gap = int(0.35 * sr); i = 0
    while i < len(a):
        if not a[i]:
            j = i
            while j < len(a) and not a[j]: j += 1
            if j - i < gap: a[i:j] = True
            i = j
        else: i += 1
    runs = []; i = 0
    while i < len(a):
        if a[i]:
            j = i
            while j < len(a) and a[j]: j += 1
            runs.append((i, j)); i = j
        else: i += 1
    b0, b1 = max(runs, key=lambda r: r[1] - r[0]) if runs else (0, len(x))
    seg = env[b0:b1]; idx = np.where(seg > thr)[0]   # tighten to actual energy (drop any bridged silence)
    if len(idx):
        b0, b1 = b0 + int(idx[0]), b0 + int(idx[-1]) + 1
    body = x[b0:b1]; benv = env[b0:b1]; dur = len(body) / sr

    F = np.abs(np.fft.rfft(body * np.hanning(len(body)))); fr = np.fft.rfftfreq(len(body), 1 / sr); P = F ** 2
    Psm = np.convolve(P, np.ones(9) / 9, mode="same"); cum = np.cumsum(P) / (np.sum(P) + 1e-12)
    lo = float(fr[np.searchsorted(cum, 0.05)]); hi = float(fr[min(np.searchsorted(cum, 0.95), len(fr) - 1)])
    peak = float(fr[np.argmax(Psm)])
    band = (fr >= lo) & (fr <= hi); Pb = P[band] + 1e-12
    flat = float(np.exp(np.mean(np.log(Pb))) / np.mean(Pb))

    def dbat(f):
        idx = min(np.searchsorted(fr, f), len(Psm) - 1); return 10 * np.log10(Psm[idx] + 1e-12)
    slope = dbat(hi) - dbat(min(hi * 2, fr[-1])); stages = 2 if slope > 15 else 1
    pk_gain = float(np.clip(10 * np.log10(np.max(Pb) / np.median(Pb)), 0, 12))

    pk = float(benv.max())
    # percussive = energy is front-loaded (sharp onset + decay), vs a sustained/building texture
    tcent = float(np.sum(np.arange(len(benv)) * benv) / (np.sum(benv) + 1e-9)) / max(len(benv), 1)
    percussive = tcent < 0.42
    if percussive:
        # sharp hit + decay, no wobble; decay ramps down over most of the clip
        attack = 0.008
        release = round(min(0.95 * dur, dur - attack - 0.01), 2)
        wobble = None
    else:
        a_idx = np.where(benv >= 0.7 * pk)[0]; attack = round(float(a_idx[0] / sr) if len(a_idx) else 0.05, 2)
        l_idx = np.where(benv >= 0.5 * pk)[0]; last = int(l_idx[-1]) if len(l_idx) else len(benv) - 1
        release = round(max(0.05, (len(benv) - last) / sr), 2)
        attack = min(attack, 0.8 * dur); release = min(release, 0.8 * dur)
        e = benv - np.mean(benv); Ef = np.abs(np.fft.rfft(e * np.hanning(len(e)))); ef = np.fft.rfftfreq(len(e), 1 / sr)
        m = (ef >= 1) & (ef <= 12); efm = ef[m]; order = np.argsort(Ef[m])[::-1]
        rates = sorted(round(float(efm[k]), 1) for k in order[:3]) if len(efm) else [4.0]
        depth = float(np.clip(np.std(benv) / (np.mean(benv) + 1e-9) * 0.4, 0.05, 0.4))
        wobble = {"rates": rates, "depth": round(depth, 2), "base": round(1 - depth, 2)}

    src = {"type": "noise"} if flat > 0.15 else {"type": "osc", "wave": "sine", "freq": round(peak)}
    filters = [{"type": "highpass", "freq": round(lo), "q": 0.7}]
    filters += [{"type": "lowpass", "freq": round(hi), "q": 0.7}] * stages
    if src["type"] == "noise" and pk_gain > 2:
        filters.append({"type": "peaking", "freq": round(peak), "q": 1.5, "gain": round(pk_gain, 1)})
    recipe = {"name": os.path.splitext(os.path.basename(path))[0], "duration": round(dur, 2), "gain": 0.9,
              "source": src, "filters": filters, "env": {"attack": attack, "release": release}}
    if wobble:
        recipe["wobble"] = wobble
    return recipe


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--preview", help="render an approximation wav to this path")
    args = ap.parse_args()
    recipe = autofit(args.input)
    print(json.dumps(recipe))
    if args.preview:
        from scipy.io import wavfile
        fs, y = render(recipe); wavfile.write(args.preview, fs, (y * 32767).astype(np.int16))


if __name__ == "__main__":
    main()
