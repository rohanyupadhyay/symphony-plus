# Quota Waits and Native Resume

Symphony treats recognized Codex quota exhaustion as a durable scheduler wait rather than an
ordinary failed attempt. This preserves work, avoids retry pressure, and keeps execution capacity
available for unrelated work.

## Signal mapping and pool scope

The Codex adapter accepts only structured HTTP-429-style app-server errors whose type is
`usage_limit_reached` or `rate_limit_exceeded`. Free-text lookalikes and authentication,
permission, billing, and transport errors retain their existing failure behavior. A signal is
normalized to the `codex` harness and a bounded, non-secret pool key derived from provider scope
and model fields. Raw provider responses are never persisted.

Codex does not currently declare an issue's quota pool before execution, so a live exhausted pool
conservatively suppresses new Codex dispatch. Durable resume reservations remain governed by the
normal global, tracker-state, and worker-host concurrency limits.

## Renewal and persistence

Future RFC 3339 renewal timestamps are honored. Missing, malformed, or past timestamps use the
configured `quota.unknown_recheck_ms` interval, which defaults to five minutes. Durable version-1
JSON records live beneath `<workspace-root>/.symphony/quota-waits/` and are written by atomic
replacement before a worker slot is released or a resume is dispatched.

Records contain only issue identity, harness and pool, wait status, renewal/recheck timestamps,
workspace key, native continuation identity, and stable outcomes. Credentials, prompts, outputs,
raw provider payloads, and authentication material are rejected or omitted.

## Native resume lifecycle

At eligibility, Symphony writes a `resuming` reservation, validates that the continuation belongs
to the same issue and workspace, then uses Codex `thread/resume` followed by a continuation turn.
The prompt directs Codex to continue remaining work from durable workspace state. Symphony never
uses `thread/start` as a fallback for quota-paused work.

If the native thread is missing, mismatched, or unavailable, the record becomes
`operator_blocked`. The workspace and workflow checkpoint remain available for diagnosis. An
operator must restore access to the original thread or explicitly revise/cancel the workflow;
automatic reconstructed continuation is intentionally unsupported.

## Operations

Terminal, HTTP, and LiveView status surfaces report quota status, pool, renewal or recheck time,
native-context availability, and stable outcome. Logs include issue/session context when known and
the same non-secret quota fields. Tracker cancellation, terminal state, label loss, and routing
changes are reconciled before resume; released records follow the ordinary workspace policy.

Claude and GitHub Copilot adapters are outside this delivery. Future adapters must implement the
same normalized signal, durable non-secret continuation identity, native-resume validation,
idempotent reservation, and operator-blocking fallback contract.
