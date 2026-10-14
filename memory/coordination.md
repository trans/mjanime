# Coordination

*Updated 2026-10-14*

Who mj corresponds with, and what is open with each. The work itself is
tracked in the code repo's `TODO.md`; this note is only the who and the
state of the conversation.

## Our address

`@mj`, set as `handle: mj` in `../config.yml` on 2026-10-14. Before that
there was no `.ai/`, so the session hook fell back to the directory name
and registered `@minanime` (sessions run from the old symlink) or
`@mjanime`, while `@mj` was registered by hand. Every other project
writes to `@mj`. The bus services are separate addresses: `mj`,
`mj:camera`, `mj:voice`.

## Correspondents

- **`@datadungeon`**: asked for `prompt_parts` on `shoot` (the seven
  picture slots). **Open:** accepting them, and fixing staging, which is
  appended after the caller's rules (`TODO.md`, "prompt parts"). Our
  proposed join order went to them 2026-10-13. Thomas asked mj
  (2026-10-14) to test whether slot order matters before anything
  changes: **run 2026-10-14, null** (`notes/prompt-slot-order-v1.md`,
  commits `81d12c1`, `569f210`). Whether the result has been sent to them
  isn't recorded here. If their order ever changes, their old records must
  keep their old join (their `handoff.md`).
- **`@overlore`** (was `@infocomics`): asked for `shoot_batch`
  (2026-10-11, mainly because shots were drawn one at a time; concurrency
  fixed that the same day, `c7181a7`). **Parked by them** the same day,
  until they build a "can wait" lane for drawing ahead, which would suit
  Google's half-price batch endpoint (not used yet). Not built.
- **`@cyclops`**: secrets and deploy conventions. Settled 2026-10-13; the
  repo `.env` stays until cyclops ships a fish export format, and it will
  ping when it does (`TODO.md`, "secrets / deploy").
- **`@arcana`**: the bus and arcana-core. Camera concurrency rides on
  arcana-core 0.17.1 (`c7181a7`).
