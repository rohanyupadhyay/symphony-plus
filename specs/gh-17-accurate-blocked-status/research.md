# Research: Accurate Blocked Session Status

## Decision 1: Normalize before rendering

**Decision**: Add a pure `SymphonyElixir.RuntimeStatus` projection boundary and invoke it when producing orchestrator snapshots. All surfaces consume its normalized lists and counts; the web presenter may normalize supplied snapshots defensively so extension callers cannot reintroduce duplicates.

**Rationale**: The terminal dashboard currently omits blocked records, while the web presenter independently counts raw `blocked` and `quota_waiting` lists. A shared read model makes one classification rule authoritative without moving mutable lifecycle ownership out of the orchestrator.

**Alternatives considered**:

- Fix each renderer independently: rejected because precedence and deduplication would drift again.
- Mutate scheduler collections to make overlap impossible: rejected because transitions can be temporarily overlapping and display correctness should not depend on mutation ordering.
- Add a second status GenServer: rejected because it creates another state owner.

## Decision 2: Use explicit precedence for overlapping records

**Decision**: Classify by issue identity with precedence `blocked > quota-waiting > retrying > running`. A quota record with status `operator_blocked` is classified as blocked even when no ordinary blocked record exists. If ordinary blocked and operator-blocked quota records overlap, merge non-secret quota diagnostics into the single blocked projection.

**Rationale**: Operator action is the most important operational truth and must not be obscured by an older running, retry, or quota representation. The precedence makes defensive overlap deterministic.

**Alternatives considered**:

- Let running win because a process may still exist: rejected because it would label paused work as healthy.
- Preserve every raw row with a warning: rejected because counts and listings would remain misleading.
- Treat every quota failure as quota-waiting: rejected because `operator_blocked` has no automatic recovery path.

## Decision 3: Expose a bounded reason

**Decision**: Build a concise reason from existing blocked error or stable outcome fields, strip control characters, collapse whitespace, and bound display length. Never derive display text from raw provider payloads, prompts, or credentials.

**Rationale**: Operators need an actionable cue, but existing error strings may be verbose or unsafe for terminal and HTML presentation. Phoenix continues to provide HTML escaping.

**Alternatives considered**:

- Display full errors unchanged: rejected for secret, control-character, and usability risk.
- Replace all reasons with generic labels: rejected because it removes required diagnostic value.

## Decision 4: Keep existing delivery and persistence

**Decision**: Retain `StatusDashboard.notify_update/1`, observability PubSub, LiveView reloads, and `QuotaWaitStore`. Do not persist ordinary blocked sessions or introduce a new event stream.

**Rationale**: The defect is in projection accuracy, not delivery or storage. Existing durable quota waits already reconstruct on restart.

**Alternatives considered**:

- Add dashboard-specific persistence: rejected as a second source of truth.
- Force browser reloads: rejected because stale classification would remain wrong, only refreshed faster.

## Decision 5: Validate pure and integrated boundaries

**Decision**: Start with focused failing tests for precedence, deduplication, operator-blocked quota conversion, safe reasons, and count/list agreement. Add orchestrator, presenter/API, terminal snapshot, and LiveView PubSub regression tests, then run `make -C elixir all`.

**Rationale**: Pure tests isolate the invariant; integrated tests prove all existing operator surfaces consume it and delivery remains coherent.

**Alternatives considered**:

- Snapshot-only UI testing: rejected because it would not prove the state projection.
- Orchestrator-only testing: rejected because the terminal omission and LiveView terminology are renderer-level failures.
