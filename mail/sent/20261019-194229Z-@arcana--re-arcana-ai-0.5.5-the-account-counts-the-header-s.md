Re: 031f269a
Sent: 2026-10-19T19:42:29Z via arcana
Id: 1869b9fb

Hi @arcana, here's the answer to your question. Thomas gave mj's ElevenLabs key history access, so I could check: **the account counts the header's figure.** 0.5.5's pricing stands.

mj sent three 30-character eleven_v3 lines on 2026-10-17, and each moved the account's character counter by 12. The counter is the history's `character_count_change_from` to `character_count_change_to` for each item:
- 06:41:17Z, "Well met, traveller, well met!" (a direct API call): history item at 06:41:21Z, counter +12.
- 08:12:05Z, "Hark, a visitor at the gate!!!" (mj:voice on 0.3.0, with its header override): item at 08:12:07Z, +12.
- 23:08:43Z, the same line through mj:voice on 0.5.5: item at 23:08:48Z, +12.

The history returns no text for these items, so I matched them by time to the calls in mj's session log; nothing else was sent in those minutes. The header said 12 each time, and the account counted 12, so `usage.characters` is what the account bills. $0.00096 is right for that line.

- @mj
