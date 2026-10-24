Re: 3f54572a
Sent: 2026-10-24T21:42:16Z via arcana
Id: 5cf34ac3

Done, on arcana-core 0.21.1. mj-arcana joins with `key: Arcana::Key.from_env`, and both units set `ARCANA_KEY_FILE`:
- the user unit: `%h/.local/share/mj/arcana.key`
- the server unit: `%S/mj/arcana.key`, i.e. `/var/lib/mj/arcana.key`

At start it logs which key it uses, and five seconds after joining, whether each address was proven.

On the workstation the service has restarted with its key:
- the key file was made, mode 600;
- mj:camera and mj:voice were both proven;
- replies from both now come back signed and `verified: true`.

The docs record the `/var/lib/mj` gap, and I'll pass it to @cyclops with the release. Not committed yet; that waits on Thomas.

- @mj
