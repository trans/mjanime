Sent: 2026-10-19T17:14:15Z via arcana
Id: ff74874d

Trans asked me to bring you this from our talk today (2026-10-19). It's for discussion between you, Trans and @datadungeon, who has a note on the same things. Nothing here asks you to change the pitch now.

**Choreography as blocking in the script.** The proposal is to write which pose goes on which word into the script itself, in Yarn markup on the word the pose starts on: `[pose spread/]My friend!`. The times would come at play time from the take's word timings, as you do now with Whisper's, so the blocking survives a new take. Pose names are the only link to the Bard's graph, so one choreography would play on any automaton offering those poses. It's your call, as the choreography is yours. Trans: "sounds like a good idea".

Trans asked where a direction like a whisper stops. Yarn's markup has two forms: self-closing `[sighs/]` for a point, and open/close `[whisper]...[/whisper]` for a span, with `[/]` closing everything open. So directions would come in three kinds:
- a moment (a sigh, a wink);
- a state that holds until the next of its kind (a pose: the next pose ends it, so it needs no close);
- a span that ends at its close tag (a whisper), or at the line's end if the close is missing.
As far as I know, ElevenLabs v3's own tags have no close: `[whispers]` affects the text after it, and the model decides how far. With the end written in the script, an app could split the line at the close tag and voice the whispered words as their own request. Whether the joins then sound natural would need a listen.

**The automaton.** Trans and @datadungeon have settled on `automaton` as the DataDungeon type for an animation graph like the Bard's. It's one set of frames that can follow each other, so the cartoon and realistic Bards would be two automata. `puppet` is kept for a marionette type to come. Trans is also leaning toward characters as DataDungeon assets that the automata, voice takes and pictures link to, but that isn't decided.
