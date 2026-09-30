# Research: Quota-Aware Harness Resume

## Decision 1: Keep scheduling ownership in the orchestrator

**Decision**: Add `quota_waits` and a derived exhausted-pool index to the existing orchestrator state. Workers report normalized quota outcomes; they do not schedule wakeups.

**Rationale**: The orchestrator already owns dispatch, retries, reconciliation, concurrency, and status snapshots. Keeping quota eligibility there preserves one idempotent authority and lets the same poll reconcile tracker eligibility before resume.

**Alternatives considered**: A quota GenServer was rejected because it splits scheduling authority. Reusing `retry_attempts` was rejected because quota waits have different accounting, pool-wide suppression, persistence, and status semantics.

## Decision 2: Persist small issue-scoped records under the workspace root

**Decision**: Store one versioned JSON record per issue in `<workspace-root>/.symphony/quota-waits/`, written atomically by temporary-file rename. Validate root and filenames before mutation and reconstruct the in-memory pool index from records.

**Rationale**: `SPEC.md` permits tracker/filesystem-driven restart recovery without a database. Host-side metadata works for local and SSH workers, survives app-server exit, and can be removed during cancellation or cleanup. Issue-scoped records minimize contention and corruption blast radius.

**Alternatives considered**: An embedded database was rejected as unnecessary complexity. Storage only inside the issue checkout was rejected because remote worker loss could make recovery unavailable. GitHub comments were rejected as a provider-specific scheduler database.

## Decision 3: Use a harness-neutral value contract with a Codex-only adapter

**Decision**: Introduce plain Elixir structs/types for `QuotaSignal` and `ContinuationReference`. Codex app-server parsing maps only documented, recognized quota errors and rate-limit metadata into that contract. Other errors retain current failure classification. Claude and GitHub Copilot receive no adapter code.

**Rationale**: The current execution layer is Codex-specific, while scheduler concepts are not. A small data contract prevents Codex-shaped orchestrator state without speculative callbacks or unused provider modules.

**Alternatives considered**: Codex maps in the orchestrator leak provider payload details. A full behaviour with placeholder adapters has no second consumer and violates simplicity.

## Decision 4: Resume a native Codex thread, never reconstruct one automatically

**Decision**: Persist the Codex `thread_id`, workspace identity, and harness identity after thread creation. On renewal, start app-server, invoke `thread/resume`, validate the resumed thread/workspace binding, then issue a continuation turn. A missing, rejected, or mismatched thread returns an operator-blocked outcome without calling `thread/start`.

**Rationale**: The approved specification requires native conversation context. A new thread seeded from files is observably different and could repeat completed work.

**Alternatives considered**: Starting a new thread was rejected by the approved Q2 answer. Keeping app-server alive until renewal was rejected because it consumes resources and cannot survive restart.

## Decision 5: Suppress by stable non-secret pool key

**Decision**: The normalized signal supplies `harness` plus `pool_key`. The orchestrator suppresses new and resumed dispatch whose route resolves to that pair. Codex uses the narrowest stable scope available; absent provider scope, the configured Codex execution identity uses one conservative default pool.

**Rationale**: Quotas are shared across tasks. Per-issue waiting launches doomed workers, while a global pause stops unrelated pools.

**Alternatives considered**: Per-issue and global suppression were rejected because each violates an explicit scope requirement.

## Decision 6: Validate renewal times; poll unknown renewal with a bounded interval

**Decision**: Accept a future UTC renewal timestamp only when parsing and sanity validation succeed. Otherwise mark renewal unknown and recheck on configurable `quota.unknown_recheck_ms`, default 300,000 ms and positive. Rechecks do not increment failure retries. Reload changes future decisions without rewriting historical signals.

**Rationale**: A bounded interval avoids tight loops without trusting malformed or stale values.

**Alternatives considered**: Failure backoff mixes categories and metrics. Indefinite blocking prevents safe automatic recovery.

## Decision 7: Treat persistence failures as safe blocks

**Decision**: Release active execution only after the quota record is durably written. If persistence or later validation fails, stop automatic dispatch for that issue, retain the workspace, expose an operator-block reason, and do not fall back to ordinary retry or a fresh thread.

**Rationale**: Continuing without durable state risks duplicate execution after restart.

**Alternatives considered**: Best-effort in-memory waiting was rejected because restart silently loses the invariant.

## Decision 8: Validate through observable lifecycle tests

**Decision**: Begin each slice with failing ExUnit tests using real orchestrator processes, temporary workspace roots, and deterministic fake tracker/Codex boundaries. Cover recognized/lookalike errors, pool suppression, slot release, restart, duplicates, renewal, second exhaustion, resume failure, cancellation, terminal cleanup, label loss, reload, malformed state, logs, status, and secret filtering.

**Rationale**: Stateful cross-lifecycle behavior requires evidence for timer, monitor, dispatch, and restart correctness.

**Alternatives considered**: Mock-only unit coverage cannot prove scheduler transitions or idempotence.
