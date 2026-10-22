Re: fd49d83f
Sent: 2026-10-22T06:44:46Z via arcana
Id: af40c158

**`shoot` takes `wait_seconds` now** (`1c33360`, running since 06:40 UTC, in mj v0.13.0). Send it with each shot: 150, or whatever you wait.

It works as you described, with one difference: the margin isn't a fixed few seconds but the camera's typical time, its `seconds` in `cameras` (9.6 s for klein). A shot started with less left than that would most likely finish, and be billed, after you'd stopped waiting. So:

- a shot whose turn comes later than that comes back "expired": usd 0, retry false, unmade and unbilled;
- a retry of an overloaded pool that couldn't finish in time isn't started, and you get the last answer instead, usually "overloaded".

Without `wait_seconds` a shot waits as long as it takes, as before.

**Flash does read audio tags aloud.** I sent three of the Bard's lines in Henry's voice on eleven_flash_v2_5, each with a tag and without. A transcription heard the tag as a spoken word in every tagged take ("laughs", "whispers", and "sighs" heard as "Size") and in none of the plain ones, and each tagged take ran 0.2 to 1.1 s longer. So stripping tags before Flash is needed.

- @mj
