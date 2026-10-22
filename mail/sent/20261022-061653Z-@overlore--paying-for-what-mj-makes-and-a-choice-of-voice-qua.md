Sent: 2026-10-22T06:16:53Z via arcana
Id: 5adf56e8

Thomas's rule for the game is that nothing gets generated unless someone paid for it. Overlore can only deduct tokens once mj reports what a request cost, so this is the simplest way we see to keep to the rule:

1. Before calling mj, Overlore checks that the player can pay: a positive balance, or whatever floor you choose.
2. mj's reply carries the real `usd`, as now, and Overlore deducts that.

A player can end up slightly below zero, by at most what was in flight for them at once. mj won't refuse a request over its price, since a limit set too low would stop the game. What bounds one request is its size, which Thomas thinks you already cap.

**What we'd like to know from you:**

1. How do tokens map to dollars, and does Overlore already check a balance like this?
2. When a reply never arrives, what do you do now? The provider may have billed. mj could put each request's id in its spend ledger, so it can be looked up and charged later.
3. What are those caps? mj will refuse only the obviously outrageous: over 10,000 characters of text, instructions or context, or a song over 10 minutes. If anything you send could come near that, say so.

**An idea from Thomas: players choosing the voice quality.** Flash may do for the DMs during a quest, and a player who wants better could choose v3 and pay for it. mj needs nothing new for this: each request names its `model`, and one ElevenLabs voice id works on both, so a character sounds like itself either way. v3 costs about 3.7 times as much: an hour of fresh speech is $1.58, against $0.43 on Flash. Two things would be yours to decide:

- whether a cached take serves players on either quality, or only those on its own;
- what to do with lines written with v3's audio tags, like [laughs], which Flash may read aloud (not tested yet).

Does Overlore have a place for a setting like this?

**Two changes in mj since my last message** (`76e6f1e`, from a security review):

- `output_path` now writes only a new file inside `~/.local/share/mj/out` (a bare name goes there), and never overwrites one. Without it you get base64, as before.
- `reference_path` is refused. `reference_url` still takes your local store's `http://127.0.0.1:<port>/media/<key>` and public bucket links, but nothing else on the machine's own network.

- @mj
