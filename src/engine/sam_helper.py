"""Segment Anything for mj's /calibrate page: SAM 2.1 kept loaded on the GPU, answering one JSON line with one JSON line.

Asked {"image": path, "points": [[x, y], ...], "labels": [1 or 0, ...], "box": [x0, y0, x1, y1] or null,
"view": [x0, y0, x1, y1] or null}, in the picture's own pixels (label 1 is "this", 0 is "not this"), it answers
{"answers": [{"outline", "corners", "area", "score", "bounds", "edge", "crop"}, ... three], "start": index, "ms": n}, or
{"error": why}. The first line it writes says it's ready: {"ready": true}.

SAM sees everything at 1024 px, so each prompt works on a crop around it, and each answer is run once more on a crop
tight around what it found, which gives its finer edges. When the view on screen is tighter than that crop would be, the
view is the crop, and nothing it answers goes outside the view: zooming in gives finer edges, and what comes back can
all be seen. SAM's scores don't say which answer is wanted (a click on a door's ring gives the ring 0.92 and the door
0.01), so `start` is chosen by size instead.

Run by src/engine/sam.cr with `python3 -P`, so the user's site-packages count and the script's own folder doesn't."""
import json, math, os, signal, sys, time
from collections import OrderedDict

MODEL = "facebook/sam2.1-hiera-base-plus"
SIDE = 1024            # what SAM sees
MASK_SIDE = 256        # what it answers in
CLICK_SIDE = 700       # the crop around a bare click
MARGIN = 1.3           # a crop's size, over what it's around
MIN_CROP = 128
MIN_VIEW = 64          # the smallest view SAM works on, either way
MIN_GAIN = 0.85        # a tight crop has to be this much smaller than the loose one to be worth running
MIN_OVERLAP = 0.6      # a tight answer has to overlap the loose one this much to replace it
MIN_SIGMA = 1.0        # the least smoothing of a mask, in pixels
EPSILON = 1.0          # how far an outline may stray from the mask, in pixels
KEPT_PICTURES = 3
KEPT_CROPS = 8

proto = sys.stdout
sys.stdout = sys.stderr  # libraries' chatter stays off the protocol
os.environ.setdefault("TRANSFORMERS_VERBOSITY", "error")
os.environ.setdefault("TQDM_DISABLE", "1")
signal.signal(signal.SIGINT, signal.SIG_IGN)  # Ctrl-C reaches us too; we stop when mj closes our stdin


def reply(obj):
    proto.write(json.dumps(obj, separators=(",", ":")) + "\n")
    proto.flush()


try:
    import numpy as np
    import torch
    import torch.nn.functional as F
    from PIL import Image
    from scipy import ndimage
    from transformers import Sam2Model

    DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
    try:
        model = Sam2Model.from_pretrained(MODEL, local_files_only=True)  # no call out when it's already here
    except OSError:
        model = Sam2Model.from_pretrained(MODEL)
    model = model.to(DEVICE).eval()
    MEAN = torch.tensor([0.485, 0.456, 0.406], device=DEVICE).view(3, 1, 1)
    STD = torch.tensor([0.229, 0.224, 0.225], device=DEVICE).view(3, 1, 1)
except Exception as err:  # noqa: BLE001 (any of these means no SAM, and the page should say why)
    reply({"error": f"SAM couldn't start: {err}"})
    sys.exit(1)

pictures = OrderedDict()
crops = OrderedDict()


def remember(cache, key, value, limit):
    cache[key] = value
    cache.move_to_end(key)
    while len(cache) > limit:
        cache.popitem(last=False)
    return value


def picture(path):
    if path in pictures:
        pictures.move_to_end(path)
        return pictures[path]
    im = Image.open(path).convert("RGB")
    im.load()
    return remember(pictures, path, im, KEPT_PICTURES)


def crop_around(x0, y0, x1, y1, W, H, side=None):
    """A square of about MARGIN times the area's longer side, centred on it and kept inside the picture"""
    side = side or int(max(x1 - x0, y1 - y0) * MARGIN)
    side = max(side, MIN_CROP)
    w, h = min(side, W), min(side, H)
    left = int(min(max((x0 + x1 - w) / 2, 0), W - w))
    top = int(min(max((y0 + y1 - h) / 2, 0), H - h))
    return left, top, w, h


def view_crop(view, W, H):
    """What's on screen as a crop, whatever its shape: SAM stretches any picture to a square anyway"""
    left, top = max(int(view[0]), 0), max(int(view[1]), 0)
    w = min(max(min(math.ceil(view[2]), W) - left, MIN_VIEW), W)
    h = min(max(min(math.ceil(view[3]), H) - top, MIN_VIEW), H)
    return min(left, W - w), min(top, H - h), w, h


def holds(crop, x0, y0, x1, y1):
    left, top, w, h = crop
    return left <= x0 and top <= y0 and x1 <= left + w and y1 <= top + h


def within(crop, outer):
    left, top = max(crop[0], outer[0]), max(crop[1], outer[1])
    return left, top, min(crop[0] + crop[2], outer[0] + outer[2]) - left, min(crop[1] + crop[3], outer[1] + outer[3]) - top


@torch.inference_mode()
def embedded(path, crop):
    key = (path, crop)
    if key in crops:
        crops.move_to_end(key)
        return crops[key]
    left, top, w, h = crop
    tile = picture(path).crop((left, top, left + w, top + h)).resize((SIDE, SIDE), Image.BILINEAR)
    pixels = torch.from_numpy(np.array(tile)).to(DEVICE).permute(2, 0, 1).float() / 255
    return remember(crops, key, model.get_image_embeddings(((pixels - MEAN) / STD)[None]), KEPT_CROPS)


def solid(mask):
    """The mask's main body with its holes filled. SAM can hang a strip of neighbouring shadow off a door by a thin neck,
    so the thin parts are opened away, the largest piece kept, and that grown back out to the mask's own edge."""
    area = int(mask.sum())
    if area == 0:
        return mask
    thin = max(1, round(area ** 0.5 / 60))
    body = ndimage.binary_opening(mask, iterations=thin)
    if not body.any():
        body = mask
    lab, n = ndimage.label(body)
    if n > 1:
        body = lab == (1 + int(np.argmax(ndimage.sum(body, lab, range(1, n + 1)))))
    return ndimage.binary_fill_holes(ndimage.binary_dilation(body, iterations=thin, mask=mask))


@torch.inference_mode()
def segment(path, crop, points, labels, box):
    """SAM's three answers on a crop: [(mask, score)], each mask the crop's size"""
    left, top, w, h = crop
    sx, sy = SIDE / w, SIDE / h
    kept = [((x - left) * sx, (y - top) * sy, l) for (x, y), l in zip(points, labels)
            if left <= x < left + w and top <= y < top + h]
    extra = {}
    if kept:
        extra["input_points"] = torch.tensor([[[[x, y] for x, y, _ in kept]]], dtype=torch.float, device=DEVICE)
        extra["input_labels"] = torch.tensor([[[l for _, _, l in kept]]], dtype=torch.long, device=DEVICE)
    if box is not None:
        extra["input_boxes"] = torch.tensor([[[(box[0] - left) * sx, (box[1] - top) * sy,
                                               (box[2] - left) * sx, (box[3] - top) * sy]]],
                                            dtype=torch.float, device=DEVICE)
    out = model(image_embeddings=embedded(path, crop), multimask_output=True, **extra)
    logits = F.interpolate(out.pred_masks[0, 0][None].float(), (h, w), mode="bilinear", align_corners=False)[0].cpu().numpy()
    # About one of SAM's mask pixels, which would otherwise show as ripples on the edge; and at least one of the picture's,
    # since on a tight crop those are finer than anything in it, and the ripples still show, as teeth
    sigma = (max(0.8 * h / MASK_SIDE, MIN_SIGMA), max(0.8 * w / MASK_SIDE, MIN_SIGMA))
    return [(solid(ndimage.gaussian_filter(m, sigma) > 0), float(s)) for m, s in zip(logits, out.iou_scores[0, 0].cpu().numpy())]


def bounds(mask):
    ys, xs = np.nonzero(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def tighter(path, loose, mask, points, labels, W, H, zoomed):
    """The answer again, on a crop tight around it, inside the view if that's what was asked about: its finer edges, or
    (loose, mask) when that's no better"""
    lx, ly, lw, lh = loose
    bx0, by0, bx1, by1 = bounds(mask)
    x0, y0, x1, y1 = bx0 + lx, by0 + ly, bx1 + lx, by1 + ly
    crop = crop_around(x0, y0, x1, y1, W, H)
    if zoomed:
        crop = within(crop, loose)
    if max(crop[2], crop[3]) > MIN_GAIN * max(lw, lh):
        return loose, mask
    left, top, w, h = crop
    box = [max(left, x0 - 4), max(top, y0 - 4), min(left + w, x1 + 4), min(top + h, y1 + 4)]
    # the loose mask in the tight crop's frame, to say which tight answer is the same thing
    frame = np.zeros((h, w), bool)
    ox, oy = max(left, lx), max(top, ly)
    ex, ey = min(left + w, lx + lw), min(top + h, ly + lh)
    frame[oy - top:ey - top, ox - left:ex - left] = mask[oy - ly:ey - ly, ox - lx:ex - lx]
    best, overlap = None, 0.0
    for m, _ in segment(path, crop, points, labels, box):
        iou = (m & frame).sum() / max(1, (m | frame).sum())
        if iou > overlap:
            best, overlap = m, iou
    return (crop, best) if overlap >= MIN_OVERLAP else (loose, mask)


STEPS = ((1, 0), (0, 1), (-1, 0), (0, -1))  # east, south, west, north


def trace(mask):
    """The mask's outer edge as a closed list of pixel corners, walked clockwise with the mask on the right. Works on
    any shape, where each row's two ends only work on a door's."""
    grid = np.pad(mask, 1)
    ys, xs = np.nonzero(grid)
    start = (int(xs[0]), int(ys[0]))  # the first pixel in reading order, so its top edge heads east
    x, y = start
    heading = 0
    path = []
    while True:
        path.append((x, y))
        x, y = x + STEPS[heading][0], y + STEPS[heading][1]
        # the two pixels ahead of this corner, to the left and right of the heading
        ahead_left = [(x, y - 1), (x, y), (x - 1, y), (x - 1, y - 1)][heading]
        ahead_right = [(x, y), (x - 1, y), (x - 1, y - 1), (x, y - 1)][heading]
        if grid[ahead_left[1], ahead_left[0]]:
            heading = (heading + 3) % 4
        elif not grid[ahead_right[1], ahead_right[0]]:
            heading = (heading + 1) % 4
        if (x, y) == start and heading == 0:
            return [(px - 1, py - 1) for px, py in path]


def simplified(path, eps):
    """Douglas-Peucker on an open run of corners"""
    keep = [0, len(path) - 1]
    runs = [(0, len(path) - 1)]
    pts = np.array(path, float)
    while runs:
        a, b = runs.pop()
        if b - a < 2:
            continue
        d = pts[b] - pts[a]
        n = np.hypot(*d) or 1.0
        mid = pts[a + 1:b] - pts[a]
        dists = np.abs(d[0] * mid[:, 1] - d[1] * mid[:, 0]) / n
        i = int(np.argmax(dists))
        if dists[i] > eps:
            k = a + 1 + i
            keep.append(k)
            runs += [(a, k), (k, b)]
    return [path[i] for i in sorted(keep)]


def outline(mask, left, top):
    """The mask's outline in the picture's pixels, closed (the last point joins the first)"""
    path = trace(mask)
    far = int(np.argmax(np.hypot(*(np.array(path, float) - path[0]).T)))
    first, second = simplified(path[: far + 1], EPSILON), simplified(path[far:] + path[:1], EPSILON)
    return [[x + left, y + top] for x, y in first[:-1] + second[:-1]]


def four_corners(points):
    """Top left, top right, bottom right, bottom left: where the outline reaches furthest along each diagonal. A
    starting place to drag from, since an ornate frame has no true corners."""
    p = np.array(points, float)
    plus, minus = p[:, 0] + p[:, 1], p[:, 0] - p[:, 1]
    return [points[int(i)] for i in (plus.argmin(), minus.argmax(), plus.argmax(), minus.argmin())]


def answer(req):
    started = time.time()
    path, points, labels, box, view = req["image"], req.get("points") or [], req.get("labels") or [], req.get("box"), req.get("view")
    W, H = picture(path).size
    wanted = [p for p, l in zip(points, labels) if l == 1]
    if box is None and not wanted:
        return {"error": "a click or a box is needed"}
    xs = [p[0] for p in wanted] + ([box[0], box[2]] if box else [])
    ys = [p[1] for p in wanted] + ([box[1], box[3]] if box else [])
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    if box is None:
        loose = crop_around(x0, y0, x1, y1, W, H, max(CLICK_SIDE, int(max(x1 - x0, y1 - y0) * MARGIN)))
    else:
        loose = crop_around(x0, y0, x1, y1, W, H)
    seen = view_crop(view, W, H) if view else None
    zoomed = seen is not None and max(seen[2:]) < max(loose[2:]) and holds(seen, x0, y0, x1, y1)
    if zoomed:
        loose = seen
    answers = []
    for mask, score in segment(path, loose, points, labels, box):
        if not mask.any():
            continue
        crop, fine = tighter(path, loose, mask, points, labels, W, H, zoomed)
        shape = outline(fine, crop[0], crop[1])
        bx0, by0, bx1, by1 = bounds(fine)
        answers.append({"outline": shape, "corners": four_corners(shape), "area": int(fine.sum()),
                        "score": round(score, 3),
                        "bounds": [bx0 + crop[0], by0 + crop[1], bx1 + crop[0], by1 + crop[1]],
                        "edge": bool(mask[0].any() or mask[-1].any() or mask[:, 0].any() or mask[:, -1].any()),
                        "crop": list(crop)})
    if not answers:
        return {"error": "SAM found nothing there"}
    return {"answers": answers, "start": start_answer(answers, box, zoomed), "ms": int((time.time() - started) * 1000)}


def start_answer(answers, box, zoomed=False):
    """Which answer to show first: the one nearest a dragged box's size, or the largest that doesn't run off its crop.
    Zoomed in, they can all run off it, and the piece clicked is then the smallest."""
    area = lambda i: answers[i]["area"]
    if box is not None:
        want = 0.9 * (box[2] - box[0]) * (box[3] - box[1])
        return min(range(len(answers)), key=lambda i: abs(area(i) - want))
    whole = [i for i, a in enumerate(answers) if not a["edge"]]
    if whole:
        return max(whole, key=area)
    return (min if zoomed else max)(range(len(answers)), key=area)


reply({"ready": True, "device": DEVICE})
for line in sys.stdin:
    try:
        reply(answer(json.loads(line)))
    except Exception as err:  # noqa: BLE001 (one bad request shouldn't end the session)
        print(f"[sam] {err!r}", file=sys.stderr)
        reply({"error": str(err)})
