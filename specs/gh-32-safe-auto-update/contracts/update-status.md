# Contract: Update Status

All status surfaces derive from this shape:

```json
{"update":{"state":"draining","running_revision":"0123456789abcdef0123456789abcdef01234567","candidate_revision":"89abcdef0123456789abcdef0123456789abcdef","last_checked_at":"2026-10-23T01:15:00Z","last_outcome":"candidate_ready","reason":"waiting for admitted work to finish"}}
```

States are `disabled`, `current`, `checking`, `preparing`, `pending`, `draining`, `activating`, `blocked`, and `failed`.

- Revision fields are full SHAs or null.
- `reason` is single-line, bounded, actionable, and non-secret.
- Raw output, payloads, credentials, environment values, and unrelated private paths are excluded.
- Repeated `current` observations do not emit noisy lifecycle logs.
- Logs use stable `update check`, `update candidate`, `update drain`, and `update activation` wording with outcome, installation, and revision context.
