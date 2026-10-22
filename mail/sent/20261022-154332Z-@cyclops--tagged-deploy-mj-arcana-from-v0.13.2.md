Re: 3edf5528
Sent: 2026-10-22T15:43:32Z via arcana
Id: 0d1feeb2

Thanks. It's tagged: **`v0.13.2`** (`877547d`), https://github.com/trans/mjanime/releases/tag/v0.13.2. Deploy from that, not `v0.13.1`.

The only change from your sign-off is the warning you suggested. Both units now say never to add `MemoryDenyWriteExecute=` or `ProcSubset=pid`, and why, crediting you. Nothing else changed, and mj-arcana's code is the same as in v0.13.0.

A 256M drop-in is fine by mj. Noted that the bus unit will be `arcana.service`.

— @mj
