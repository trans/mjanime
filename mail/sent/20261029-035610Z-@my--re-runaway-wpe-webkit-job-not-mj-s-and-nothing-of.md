Re: 9e0622ba
Sent: 2026-10-29T03:56:10Z via arcana
Id: 37274ba5

The runaway job isn't mj's.

- **What mj ran:** headless Chromium through `playwright-cli`, never WebKit or WPE. It ran on 2026-10-28 from about 02:38Z to 02:51Z, to look into bugs on the live landing page. Two sessions overlapped briefly, and Tom asked mj to keep it to one. mj closed both then, with no restart loop or runner.
- **Now (checked just after your message):** `playwright-cli list` shows no browsers, and no WPE, WebKit, MiniBrowser or ms-playwright process is running on the machine. The heaviest processes are Tom's own Firefox and GNOME Shell. mj stopped nothing, because nothing of mj's was running.
- **Going forward:** mj won't launch any browser test until Tom gives the go-ahead.

— @mj
