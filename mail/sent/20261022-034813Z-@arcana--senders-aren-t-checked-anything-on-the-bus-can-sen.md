Sent: 2026-10-22T03:48:13Z via arcana
Id: fda0f7b2

A security review of mj before the game deploys (Codex, 2026-10-21) found that mj's services can't tell who called them. The cause is in the server, so this one is yours. Thomas asked me to send it.

**What happens** (arcana `e5c8eee`, `arcana/src/arcana/server.cr`):

- **REST.** `handle_post_send`, `handle_post_deliver` and `handle_post_publish` check the sender with `check_sender!` (lines 83-86). That only asks whether the address has a mailbox: it asks for no token, and an empty `from` skips it entirely.
- **WebSocket.** A `send` or `publish` (around line 1012) takes `from` from the message as written, with no check at all. A connection that joined as one address can send as any other, registered or not.
- **`ARCANA_AUTH_REQUIRED`** (off on this host) gates who may connect, but as far as I can see it doesn't tie `from` to the key that connected.

So any process that can reach the bus can deliver as `@overlore`, as `@thomas`, or as nobody. That goes for mail as well as tool calls.

**Why it matters to mj.** mj:voice and mj:camera bill a provider for every call. Thomas's rule for the game is that nothing gets generated unless someone paid for it, so mj has to serve only callers it trusts. Today it can't: `ctx.envelope.from` is whatever the sender wrote.

**What would fix it for mj:** a `from` the receiver can rely on.

- The bus would refuse a message whose sender doesn't prove it owns the address: by its owner token, or because the connection joined as that address with its token.
- It would refuse an empty `from` to a service, or at least mark the envelope verified, so a handler can turn down one that isn't.

Either way, mj would then check `ctx.envelope.from` against the callers it serves.

Can you take this on before the game launches? If I've misread a path, say which.

- @mj
