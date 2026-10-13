# Data Model: Accurate Blocked Session Status

## Runtime Record

An existing scheduler-owned record for one issue in one internal collection.

Fields used by projection:

- `issue_id`: stable identity; required for classification.
- `identifier`: human-readable issue key when available.
- `issue_url`: optional safe tracker link.
- `state`: optional tracker workflow state; supplementary only.
- `worker_host`, `workspace_path`, `session_id`: optional execution context.
- lifecycle-specific timestamps and diagnostic fields.

Runtime records may temporarily overlap across `running`, `retrying`, `blocked`, and `quota_waiting`. Overlap is an input condition, not a second public status.

## Quota Wait Record

An existing durable quota record reconstructed by the orchestrator.

Relevant fields:

- `status`: `waiting`, `resuming`, or `operator_blocked`.
- `harness`, `pool_key`: bounded non-secret quota identity.
- `renewal_at`, `next_recheck_at`: automatic recovery timing.
- `native_context_available`: whether the original session can be resumed.
- `last_outcome`: stable non-secret recovery outcome.
- `updated_at`: last durable transition time.

Validation rules:

- `operator_blocked` maps to primary classification `blocked`.
- Other quota statuses map to `quota_waiting` while automatic recovery remains possible.
- Raw provider responses, prompts, credentials, and authentication material are never projected.

## Normalized Runtime Status Entry

The read-only operator projection for exactly one `issue_id`.

Fields:

- `classification`: exactly one of `running`, `retrying`, `quota_waiting`, or `blocked`.
- issue identity and safe location context from the highest-precedence available record.
- `tracker_state`: optional supplementary provider workflow state.
- `reason`: control-character-free, whitespace-collapsed single-line text of at most 160 Unicode graphemes including any truncation marker; absent source text projects as `Operator action required` for blocked entries.
- lifecycle detail: running metrics, retry timing, quota timing/context, or blocked context.
- `quota_context`: present on quota-derived blocks so diagnosis retains harness, pool, continuation availability, outcome, and relevant time.

Invariants:

1. One `issue_id` produces at most one normalized entry.
2. Primary precedence is `blocked > quota_waiting > retrying > running`.
3. `operator_blocked` quota state participates in the blocked tier.
4. Counts are derived from normalized entries, never raw collection lengths.
5. Primary lists partition the same normalized entry set.
6. Tracker workflow state never changes `classification`.
7. A recoverable quota entry without renewal or recheck timing exposes `Renewal time unavailable` rather than inventing a timestamp.

## Status Snapshot

A coherent read model containing mutually exclusive `running`, `retrying`, `quota_waiting`, and `blocked` lists; counts derived from those exact lists; and unchanged token totals, rate limits, and polling metadata.

State transitions:

```text
running -> retrying -> running
running -> blocked -> running/released
running -> quota_waiting -> resuming -> running
quota_waiting -> blocked (operator_blocked)
any active status -> absent (cancelled, terminal, ineligible, or cleaned up)
quota_waiting -> quota_waiting (restart reconstruction)
```

The first completed snapshot after a transition reflects only the destination classification. An older browser frame may exist until PubSub delivery, but the replacement frame is internally coherent.
