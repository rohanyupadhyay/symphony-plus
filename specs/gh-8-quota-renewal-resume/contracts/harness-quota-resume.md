# Harness Quota/Resume Contract

## Normalized run outcome

A harness run returns `completed`, `failed`, `quota_exhausted`, or `operator_blocked`.
`quota_exhausted` includes required `harness`, stable non-secret `pool_key`, optional validated
`renewal_at`, optional issue/workspace-bound `continuation_reference`, and an allowlisted
`reason_category`. Free-form text containing "limit", "quota", or "rate" is insufficient for
classification; tests pin every accepted Codex protocol shape.

## Native resume request

Inputs are validated issue/workspace identity, a Codex continuation reference, continuation
guidance, and normal approval/sandbox/tool config from `SymphonyElixir.Config`.

Required behavior:

1. Start app-server in the validated issue workspace.
2. Initialize and call Codex `thread/resume` with saved `thread_id`.
3. Reject missing, not-found, malformed, or workspace-mismatched threads.
4. On success, call `turn/start` on the same thread with continuation guidance.
5. Preserve usual session identity and cumulative token/rate-limit updates.
6. Never call `thread/start` as fallback during quota resume.

Outputs retain the four normalized categories; resume validation failure is `operator_blocked`.

## Scheduler obligations

- Persist quota state before releasing running state.
- Exclude waits from concurrency and retry counters.
- Suppress all dispatch mapped to an exhausted pool.
- Reconcile tracker eligibility before reservation.
- Persist `resuming` before launch for poll/restart idempotence.
- On resume failure preserve workspace/workflow artifacts and expose an operator block.

## Future adapter obligations

Future Claude or GitHub Copilot adapters must provide identical normalized outcome, stable non-secret
pool semantics, validated renewal timing, native continuation binding, and explicit resume failure.
An adapter unable to resume native context cannot opt into automatic continuation.
