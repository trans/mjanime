# Calibrate

`/calibrate.html` in `mj serve`: load a picture, mark it up, save the marks as JSON, in the picture's own pixels. It's
how a hall's doors and plaques get marked for @overlore's game. Run `just serve`, then open
<http://localhost:21683/calibrate.html>.

| Tool | Key | Makes |
| --- | --- | --- |
| Point, Line, Rect, Ellipse | P L R E | those shapes: drag to draw |
| Corners | C | four corners: drag a box, then drag each corner |
| SAM | S | an outline or four corners, from Segment Anything |
| Pan | H | also space, or the middle button |

Click a shape to select it, and drag its handles or an outline's points. Double-click to label it. Arrows nudge,
Del deletes, Ctrl+Z undoes, the wheel zooms, F fits.

## SAM

Segment Anything outlines a shape from a click. It runs here, on the GPU, and costs nothing.

- **Click** a shape, or **drag a loose box** around it. Further clicks add to it.
- **Shift-click** (or alt-click, or right-click) marks what it shouldn't take. A window manager may take alt-click.
- **Tab** steps through its three answers, or **1 2 3** picks one. They're usually a part of the thing, the thing, and
  the thing with its surroundings. Its scores don't say which is wanted, so don't go by them: a click on a door's ring
  scores the ring 0.92 and the door 0.01.
- **A** adds the answer to the outline under it, **X** cuts it from that outline (see below).
- **Enter** keeps it as its own outline, **C** as four corners. **Backspace** takes back a click, **Esc** cancels.

A click starts on the largest answer, and a box on the answer nearest its own size. So use a box for a plaque: a click
on one starts on the door, arch and plaque together.

Four corners are where the outline reaches furthest along each diagonal. An ornate frame has no true corners, so they
are a place to drag from.

Keeping a shape over one of its own type replaces it and keeps its label, so a bad outline can be redone by clicking the
door again. On a picture named `hall-*`, new shapes are labelled in order, left to right: `red sun tree big moon trident
brown` for outlines, the same without `big` for corners.

### Fixing an edge

Zoom in on the bad stretch, click the part that's wrong, and press **X** to cut it, or **A** to add it. The session ends
and the view stays, so the next click starts on the next piece. Ctrl+Z undoes.

- **Zooming in gives finer edges.** Once the view is tighter than what SAM would crop for itself (under about 700 px
  across, or about 2.7× in a 1900 px window), SAM looks at the view and nothing else, and its answer can't reach past
  what's on screen. It also means a piece stops at the edge of the screen: overlap the views along a long edge. The
  panel says what SAM saw.
- **Which outline** is the one the piece shares the most with, or the nearest within 24 px. It's drawn in white while
  you choose, and the panel names it. With none, **A** starts a new outline, so a door can also be built up from small
  pieces.
- **Only what's near the piece changes.** Every point away from it stays exactly where it was, however many fixes are
  made.
- **A piece never quite meets the old edge,** so strips under about 6 px wide beside it are cleared too: a crust left
  outside a cut, a slit left by an add. An add therefore joins a piece up to about 6 px short of the outline. Further off
  it's refused.
- **An outline is one solid shape.** A cut wholly inside it is refused, since it can't have a hole. A cut that splits it
  keeps the larger part, and says so.
- In the SAM tool an outline's points don't drag, or they'd take every click near its edge. Press **P** to move them
  by hand. Four corners still drag.

SAM still can't say where a door ends inside black shadow. Zoomed in, it follows a soft edge better but can wander in a
flat black band, and on the golden hall it gives rough edges there. On the 3d sun door, six fixes took @overlore's first
outline from a worst miss of 9.1 px and a mean of 1.16 px to 2.5 px and 0.87 px, against 36 points placed by hand.

**The first ask takes about 5 s**, to start SAM. After that a click takes under a second, and asking again in the same
place about 0.15 s. SAM holds about 1.3 GB of graphics memory, and stops after 15 minutes unused or when `mj serve` does.

It needs `python3` with `torch`, `transformers`, `scipy`, `numpy` and `Pillow`. The model
(`facebook/sam2.1-hiera-base-plus`, about 325 MB) downloads on first use. The other tools need none of this, nor even
the server.

## Files

**Save JSON** writes `<picture>.calib.json`:

```json
{"type": "mj-calibration", "version": 1,
 "image": {"name": "hall-silver.png", "width": 3344, "height": 932, "data": null},
 "shapes": [
   {"type": "outline", "label": "sun", "color": "#ff00ff", "points": [[571, 382], [580, 370]]},
   {"type": "quad", "label": "sun", "color": "#ff00ff", "points": [[598, 261], [766, 283], [762, 360], [595, 345]]}
 ]}
```

An `outline` is closed: its last point joins its first. A `quad` runs top left, top right, bottom right, bottom left.
The older shapes are `point` (`x`, `y`), `line` (`x1`, `y1`, `x2`, `y2`), `rect` and `ellipse` (`cx`, `cy`, `rx`, `ry`, and an
ellipse's `rotation`).

**Load JSON** opens that, or a `doors.json` from @overlore's SAM run
(`{image, width, height, doors: {name: [[x, y], ...]}}`) as labelled outlines on the picture already loaded. It asks
first if the file names a different picture, and refuses a different size. Shapes from one hall can be loaded onto the
next and nudged: load the image first, and leave "embed image" off.

## How it's built

`public/calibrate.html` sends its picture once (`POST /calibrate/sam/image`), and then its clicks (`POST /calibrate/sam`).
`src/engine/sam.cr` passes them to `src/engine/sam_helper.py`, a Python process that keeps the model loaded and answers
one JSON line with one JSON line. Pictures wait in a temporary folder that goes when the server stops.

Each answer runs twice: on a crop around the prompt, or the view if that's tighter, then on a crop tight around what it
found, because SAM sees everything at 1024 px and answers at 256. Its mask is smoothed, by at least a picture pixel since
tight crops otherwise show SAM's ripples as teeth, then cleaned of anything joined on by a thin neck: on silver's brown
door it had hung a strip of the arch's shadow off the door.

**A** and **X** run in the page, without the server (`reshape`). Both shapes are filled in as pixels, the piece laid over
the outline, thin strips beside it cleared, and the edge walked again, keeping each old point the change didn't reach.
