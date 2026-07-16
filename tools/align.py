#!/usr/bin/env python3
"""
Audio-aligned retiming across a HUB-CONNECTED GRAPH of clips.

Give one or more base clips (all sharing the same 'hub' first frame) plus a mouth-openness
chart per clip. They're pooled into one set of real frames; the search finds a PATH that best
matches a voice track's energy — playing each clip FORWARD or BACKWARD, slowing/speeding, and
HOPPING between clips only at the shared hub (so switches are seamless). Real frames, no
generation. (3 clips, each forward/back, joined at the hub = the "9 combos" to choose from.)

  m_src[f] = mouth openness of pooled frame f (from the charts)
  m_tgt[t] = desired openness at output time t (from audio RMS)
  minimize sum|m_src[path]-m_tgt| + move penalties, Viterbi DP with hub-hops.

Single clip:   align.py --clip a.mp4 --audio v.wav --src-openness a.csv --out out.mp4
Clip graph:    align.py --clips a.mp4,b.mp4,c.mp4 --audio v.wav --src-openness a.csv,b.csv,c.csv --out out.mp4
"""
import argparse, os, subprocess
import numpy as np, cv2

def norm(x):
    x = np.asarray(x, float); r = x.max() - x.min()
    return (x - x.min()) / r if r > 1e-9 else np.zeros_like(x)

def read_frames(clip):
    cap = cv2.VideoCapture(clip); fr = []
    while True:
        ok, f = cap.read()
        if not ok: break
        fr.append(f)
    cap.release(); return fr

def roi_openness(frames, roi):
    x, y, w, h = roi; raw = []
    for f in frames:
        g = cv2.cvtColor(f[y:y+h, x:x+w], cv2.COLOR_BGR2GRAY).astype(float)
        raw.append((g < np.percentile(g, 25)).mean() + 0.002 * np.abs(cv2.Sobel(g, cv2.CV_64F, 0, 1, ksize=3)).mean())
    return np.convolve(norm(raw), [0.25, 0.5, 0.25], mode="same")

def audio_openness(wav, n_out):
    try:
        import librosa
        y, sr = librosa.load(wav, sr=None, mono=True)
        rms = librosa.feature.rms(y=y, frame_length=1024, hop_length=256)[0]
    except Exception:
        import wave
        wf = wave.open(wav, "rb"); y = np.frombuffer(wf.readframes(wf.getnframes()), np.int16).astype(float)
        if wf.getnchannels() > 1: y = y[::wf.getnchannels()]
        rms = np.array([np.sqrt((y[i:i+1024]**2).mean() + 1e-9) for i in range(0, max(1, len(y)-1024), 256)])
    env = norm(rms); xs = np.linspace(0, len(env) - 1, n_out)
    return norm(np.interp(xs, np.arange(len(env)), env))

def warp(m_src, m_tgt, hold, fast, maxstep):
    # MONOTONIC time-warp: play a fixed candidate FORWARD only, slowing (hold) or speeding
    # (fast) to match the audio. No reverse — the candidate already bakes in its one reverse
    # (its first half is a clip played backward). Returns (path indices, total cost).
    N, T = len(m_src), len(m_tgt)
    emit = np.abs(m_src[None, :] - m_tgt[:, None]); INF = 1e18
    dp = np.full((T, N), INF); bp = np.zeros((T, N), int); dp[0] = emit[0]
    def tc(mv): return 0.0 if mv == 1 else (hold if mv == 0 else fast * (mv - 1))
    for t in range(1, T):
        prev = dp[t-1]; cur = np.full(N, INF); arg = np.arange(N)
        for f in range(N):
            best = INF; a = f
            for mv in range(0, maxstep + 1):
                pf = f - mv
                if pf >= 0:
                    c = prev[pf] + tc(mv)
                    if c < best: best = c; a = pf
            cur[f] = best; arg[f] = a
        dp[t] = cur + emit[t]; bp[t] = arg
    f = int(np.argmin(dp[-1])); path = [f]
    for t in range(T-1, 0, -1): f = bp[t][f]; path.append(f)
    path.reverse(); return path, float(dp[-1].min())

def build_candidates(clip_frames, clip_open):
    # Every "reverse(X) then forward(Y)" pairing: leaf_X -> hub -> leaf_Y, seamless at the hub
    # (both halves meet on frame 0). Returns list of (label, src, openness) where
    # src[i] = (clip_idx, frame_idx) of candidate frame i.
    n = len(clip_frames); cands = []
    for x in range(n):
        for y in range(n):
            fx, fy = len(clip_frames[x]), len(clip_frames[y])
            src = [(x, fx-1-i) for i in range(fx)] + [(y, i) for i in range(fy)]
            op = np.concatenate([clip_open[x][::-1], clip_open[y]])
            cands.append((f"rev{x}->fwd{y}", src, op))
    return cands

def align_graph(m_src, m_tgt, seg, hubs, hold, rev, fast, maxstep, hubcost):
    N, T = len(m_src), len(m_tgt)
    emit = np.abs(m_src[None, :] - m_tgt[:, None]); INF = 1e18
    dp = np.full((T, N), INF); bp = np.zeros((T, N), int); dp[0] = emit[0]
    def tc(mv): return 0.0 if mv == 1 else (hold if mv == 0 else (rev * abs(mv) if mv < 0 else fast * (mv - 1)))
    hl = list(hubs)
    for t in range(1, T):
        prev = dp[t-1]; cur = np.full(N, INF); arg = np.arange(N)
        for f in range(N):                                   # moves stay WITHIN a clip's segment
            s0, s1 = seg[f]; best = INF; a = f
            for mv in range(-maxstep, maxstep + 1):
                pf = f - mv
                if s0 <= pf <= s1:
                    c = prev[pf] + tc(mv)
                    if c < best: best = c; a = pf
            cur[f] = best; arg[f] = a
        if len(hl) > 1:                                      # hop between clips only at the shared hub
            for f in hl:
                for h in hl:
                    if h != f and prev[h] + hubcost < cur[f]:
                        cur[f] = prev[h] + hubcost; arg[f] = h
        dp[t] = cur + emit[t]; bp[t] = arg
    f = int(np.argmin(dp[-1])); path = [f]
    for t in range(T-1, 0, -1): f = bp[t][f]; path.append(f)
    path.reverse(); return path

def render(frames, path, fps, audio, out, sigma=1.6, jump=4):
    # Smooth holds into slow-mo, but NOT across hub-hops: a big index jump is a seamless
    # cut between two hub frames — smoothing across it would interpolate through frames the
    # path never took. Split the path into continuous runs at those hops, smooth each alone.
    from scipy.ndimage import gaussian_filter1d
    path = np.asarray(path, float)
    breaks = [0] + [i for i in range(1, len(path)) if abs(path[i] - path[i-1]) > jump] + [len(path)]
    pos = []
    for a, b in zip(breaks[:-1], breaks[1:]):
        run = path[a:b]
        pos.extend(gaussian_filter1d(run, sigma) if len(run) >= 3 else run)
    p = np.clip(np.asarray(pos), 0, len(frames) - 1)
    h, w = frames[0].shape[:2]; tmp = out + ".s.mp4"
    vw = cv2.VideoWriter(tmp, cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for pos in p:
        i = int(pos); fr = pos - i; j = min(i + 1, len(frames) - 1)
        vw.write(frames[i] if fr < 1e-3 else cv2.addWeighted(frames[i], 1 - fr, frames[j], fr, 0))
    vw.release()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-i", audio, "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", out], check=True)
    os.remove(tmp)

def main():
    a = argparse.ArgumentParser()
    a.add_argument("--clip"); a.add_argument("--clips")
    a.add_argument("--audio", required=True); a.add_argument("--out", required=True)
    a.add_argument("--src-openness"); a.add_argument("--roi")
    a.add_argument("--fps", type=float, default=24)
    a.add_argument("--hold", type=float, default=0.3); a.add_argument("--rev", type=float, default=0.4)
    a.add_argument("--fast", type=float, default=0.3); a.add_argument("--maxstep", type=int, default=2)
    a.add_argument("--hubcost", type=float, default=0.15, help="cost to hop to another clip at the hub")
    A = a.parse_args()

    dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                         "-of", "default=nw=1:nk=1", A.audio]).decode().strip())
    T = int(round(dur * A.fps)); m_tgt = audio_openness(A.audio, T)

    if A.clips:
        # 9-candidate model: start at a leaf, reverse into the hub, forward out to a leaf.
        # Each candidate = reverse(X)+forward(Y); pick the one that best matches the voice,
        # slight slow/fast only (one clean direction change, at the hub — no stutter).
        clips = A.clips.split(","); charts = A.src_openness.split(",")
        CF = [read_frames(c) for c in clips]
        CO = []
        for cf, ch in zip(CF, charts):
            c = np.loadtxt(ch)
            CO.append(norm(np.interp(np.linspace(0, len(c) - 1, len(cf)), np.arange(len(c)), c)))
        best = None
        for label, src, op in build_candidates(CF, CO):
            op = norm(op); path, cost = warp(op, m_tgt, A.hold, A.fast, A.maxstep)
            err = float(np.mean(np.abs(op[path] - m_tgt)))
            d = np.diff(path); slow = float(np.mean(d == 0))
            if best is None or cost < best[0]:
                best = (cost, label, src, path, err, slow, len(op))
            print(f"  {label:14s} len={len(op):3d} cost={cost:7.2f} err={err:.3f} slow={slow:.2f}")
        cost, label, src, path, err, slow, clen = best
        print(f"WINNER {label} out={T} cand_len={clen} align_err={err:.3f} slow-mo={slow:.2f}")
        frames = [CF[c][f] for (c, f) in src]
    else:
        frames = []; m_src = []; seg = []; hubs = []
        clips = [A.clip]; charts = A.src_openness.split(",") if A.src_openness else [None]
        for clip, chart in zip(clips, charts):
            fr = read_frames(clip); s0 = len(frames); frames += fr; s1 = len(frames) - 1
            hubs.append(s0); seg += [(s0, s1)] * len(fr)
            if chart:
                c = np.loadtxt(chart)
                m_src += list(norm(np.interp(np.linspace(0, len(c) - 1, len(fr)), np.arange(len(c)), c)))
            else:
                m_src += list(roi_openness(fr, tuple(int(v) for v in A.roi.split(","))))
        m_src = norm(np.asarray(m_src))
        path = align_graph(m_src, m_tgt, seg, set(hubs), A.hold, A.rev, A.fast, A.maxstep, A.hubcost)
        d = np.diff(path); err = float(np.mean(np.abs(m_src[path] - m_tgt)))
        print(f"pool={len(frames)} out={T} align_err={err:.3f} "
              f"fwd={np.mean(d==1):.2f} rev={np.mean(d<0):.2f} hold={np.mean(d==0):.2f}")
    render(frames, path, A.fps, A.audio, A.out)
    print("wrote", A.out)

if __name__ == "__main__":
    main()
