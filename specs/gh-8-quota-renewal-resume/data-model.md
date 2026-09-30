# Data Model: Quota-Aware Harness Resume

## Quota Pool

| Field | Type | Constraints |
|-------|------|-------------|
| `harness` | enum/string | Required; initial supported value `codex`. |
| `pool_key` | string | Required, stable, non-empty, non-secret, bounded; never derived from credentials. |

Identity is `{harness, pool_key}`. The orchestrator derives the exhausted-pool index from waits.

## Continuation Reference

| Field | Type | Constraints |
|-------|------|-------------|
| `harness` | enum/string | Required; must match the wait harness. |
| `native_id` | string | Required for automatic resume; Codex stores `thread_id`. |
| `issue_id` | string | Required immutable issue binding. |
| `workspace_key` | string | Required; resolves to the same validated workspace. |

No prompt, output, raw provider payload, token, or authentication material is stored.

## Quota Wait

| Field | Type | Constraints |
|-------|------|-------------|
| `version` | positive integer | Required; initial `1`; unknown versions fail closed. |
| `issue_id` | string | Required unique record key. |
| `issue_identifier` | string | Required operator identifier. |
| `harness` | string | Required; initial `codex`. |
| `pool_key` | string | Required validated non-secret scope. |
| `status` | enum | `waiting`, `eligible`, `resuming`, or `operator_blocked`. |
| `renewal_at` | UTC timestamp/null | Future validated instant or null. |
| `next_recheck_at` | UTC timestamp | Required renewal eligibility or bounded recheck. |
| `workspace_key` | string | Required and validated under workspace root. |
| `continuation` | Continuation Reference/null | Required for automatic resume; null blocks. |
| `last_outcome` | enum/string | Stable category, never raw provider text. |
| `observed_at` | UTC timestamp | Latest accepted quota signal. |
| `updated_at` | UTC timestamp | Latest durable transition. |

Only allowlisted fields serialize; paths, credentials, payloads, prompts, and output are forbidden.

## Resume Dispatch

Ephemeral idempotence reservation represented by durable `resuming` status before worker launch.
It records `issue_id`, a wait-version token, continuation reference, and reservation time. On
restart, `resuming` returns to `eligible` only after confirming no live run exists.

## Run Attempt Extension

Run metadata gains `run_kind` (`new`, `continuation`, `failure_retry`, `quota_resume`), optional
`continuation_reference`, and optional `quota_pool`. Quota signals do not increment retry attempts;
operator-blocked transitions create no run.

## State Transitions

```text
running --recognized quota + durable write--> waiting
waiting --not due--> waiting
waiting --tracker ineligible/terminal--> removed (normal retention/cleanup)
waiting --valid continuation + due--> eligible --atomic reservation--> resuming
waiting --missing/invalid continuation--> operator_blocked
resuming --thread resumed + turn starts--> running (quota_resume)
resuming --quota still exhausted--> waiting (latest valid signal)
resuming --native resume unavailable--> operator_blocked
operator_blocked --tracker ineligible/terminal--> removed
```

## Invariants

1. An issue appears in at most one of running, retrying, quota-waiting, or blocked state.
2. At most one active run or `resuming` reservation exists per issue.
3. A waiting/resuming record suppresses its pool until eligible; unrelated pools remain dispatchable.
4. Automatic resume requires a native reference bound to the same issue and workspace.
5. Removing a wait uses ordinary reconciliation and workspace-cleanup authority.
6. Persist-before-release and persist-before-resume prevent restart from causing fresh dispatch.
