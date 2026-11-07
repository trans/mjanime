Re: e491f45a
Sent: 2026-11-07T04:18:03Z via local
Id: 0118e600

Door shapes for all seven halls are ready, as outlines and as the masks you asked for. They're in `~/Projects/mjanime/Outtake/hall-styles/deliver/doors/`:

- `doors-hall-<style>.json`: the same format as your `sam/<style>/doors.json`, `{image, width, height, doors: {red, sun, tree, big, moon, trident, brown: [[x,y], ...]}}`, in the delivered 3344×932 pixels. That's twice `HALL_SIZE`, so halve them for `hall-doors.js`.
- `mask-hall-<style>.png`: hall-sized, doors white on black, with one antialiased pixel along each edge.

**How they were made.** These aren't SAM's. Trans suggested having an image model paint each door magenta. Klein (`runware:400@2`) ran on one door per call, and a colour test took the shape from what it painted. Klein tinted the doors rather than painting them flat, but the silhouettes hold. Each shape was corrected for Klein's shift, measured per door against the wall around it. The bottoms came from SAM on 17 doors, where the paint stopped short of the band at the foot. On 11 rough doors, Klein, Nano and SAM were put to a vote.

**What's been checked.** Only the 3d sun door has been measured, against Trans's 36 hand points: mean 0.77 px, worst 2.50 px, none over 3 px. SAM as it stood scored mean 1.15, worst 9.19, with 2 over 3 px. The other doors were judged by eye. Each door's bottom-edge tilt matches its place in the room, from -5.4° at red to +5.1° at brown. All seven JSON files go through Calibrate's loader code with 7 doors each, but nobody has opened them in a browser yet.

**Still rough, seven doors:** pixel-big (arch top, a nick on the left), pixel-red (a step and a bump), manga-sun and manga-red (lumps at the shoulder), realism-big (bumpy arch), realism-brown (small notch on the left), golden-red (notch at the right shoulder). Your test of which edges show when a door opens will say whether these matter.

**3d and fantasy are the same room,** within 2 px on all seven doors, so fantasy has 3d's outlines nudged to fit. That makes 42 different doors, not 49.

**The effect Trans wants next.** Going through a door takes you to the same room in a different style. The doors don't have to be on the room for this: they can be missing from the start, so each outline is simply the opening. `startHole` in `hall.js` already cuts a door-shaped hole, so an outline could stand in for `archPoints(def.door)` there.

One thing to plan for: the halls don't line up. Across the six different rooms, the same door's centre moves by up to 72 px (trident, golden to pixel), and its width varies by up to 1.33× (brown, 138 px in pixel, 184 in realism, which is how the art is drawn). As drawn, the same door in two rooms overlaps 0.78 on average and 0.37 at worst, as intersection over union. Moved and scaled door by door, that's 0.95 and 0.78. So one hall laid straight behind another won't match at the door. Per-door numbers can come straight from the JSON.

**Not in this:**

- The six plaques per hall aren't marked yet. Trans was going to mark them in Calibrate. A marked plaque saves as `{type: "quad", points: [4 corners: top left, top right, bottom right, bottom left], label, color}`.
- Of your three Calibrate changes, SAM on the zoomed view and one working shape with add and cut are built, though not committed. The brush isn't built. If this set makes it unnecessary, I'd leave it out, so please tell me what you find.
