# Feature Specification: Accurate Blocked Session Status

**Feature Branch**: `symphony/gh-17-accurate-blocked-status`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "The Symphony Plus UI/dashboard is not displaying accurately when a session is stuck on a quota issue or blocked for any other reason."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Identify Paused Work Accurately (Priority: P1)

As an operator, I can see that a session is paused, why it is paused, and what kind of intervention or wait is required, so I do not mistake blocked work for healthy running work.

**Why this priority**: Accurate current status is the primary operational need and prevents wasted diagnosis or unsafe attempts to dispatch duplicate work.

**Independent Test**: Present snapshots containing an ordinary operator-input block, a renewable quota wait, and an unrecoverable quota-resume block; each issue appears with one primary lifecycle status and a matching reason.

**Acceptance Scenarios**:

1. **Given** a session is waiting for operator input or approval, **When** an operator views the dashboard or JSON status, **Then** the issue is identified as blocked and its concise blocking reason is visible.
2. **Given** a session is waiting for quota renewal or a scheduled quota recheck, **When** status is viewed, **Then** the issue is identified as quota-waiting with its pool and next renewal or recheck time.
3. **Given** quota recovery cannot resume the original session and requires operator action, **When** status is viewed, **Then** the issue is identified as operator-blocked rather than as an ordinary renewable quota wait.
4. **Given** a blocked issue retains an active tracker workflow state, **When** status is viewed, **Then** that tracker state does not replace or visually obscure the runtime blocked status.

---

### User Story 2 - Trust Dashboard Counts (Priority: P2)

As an operator, I can rely on summary counts and status tables to describe distinct issues, so capacity and intervention decisions are based on an accurate inventory.

**Why this priority**: Counts summarize the same lifecycle truth as the detail rows and must not inflate the amount of paused work.

**Independent Test**: Present a mixed snapshot and show that every paused issue contributes to exactly one primary status count and one corresponding primary status listing.

**Acceptance Scenarios**:

1. **Given** one quota recovery has become operator-blocked, **When** summary counts are generated, **Then** that issue is counted once as blocked and is not also counted as a renewable quota wait.
2. **Given** multiple running, retrying, quota-waiting, and blocked issues, **When** status is rendered, **Then** the summary counts equal the distinct rows in their respective primary status groups.

---

### User Story 3 - Preserve Accurate Status Through Transitions (Priority: P3)

As an operator, I continue to see accurate status while a session moves into, remains in, recovers from, or is removed from a paused condition.

**Why this priority**: A correct one-time display is insufficient for a long-running scheduler whose state changes and quota waits may survive restart.

**Independent Test**: Exercise block, quota wait, operator-blocked fallback, recovery, cancellation, terminal cleanup, and restart paths and observe that no stale or duplicate primary status remains.

**Acceptance Scenarios**:

1. **Given** a blocked session resumes or leaves the active workflow, **When** the next status snapshot is produced, **Then** its prior blocked representation and count are removed.
2. **Given** a durable quota wait survives an orchestrator restart, **When** status is reconstructed, **Then** its primary status, reason, and timing remain accurate.
3. **Given** status changes while the dashboard is open, **When** the dashboard receives its normal update, **Then** the visible count, row, status, and reason agree without requiring a manual reload.

### Edge Cases

- A quota wait has neither a provider renewal time nor a known native continuation.
- A quota wait transitions to operator-blocked while an older dashboard snapshot is being replaced.
- A blocked entry has no session identifier, last agent event, or tracker workflow state.
- The same issue is defensively present in more than one internal runtime collection during a transition.
- A long or control-character-containing failure reason must remain concise and safe to display.
- Snapshot retrieval times out or the orchestrator is unavailable; the existing unavailable-state behavior remains distinct from an issue-level block.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every issue in an operator status snapshot MUST have exactly one primary runtime lifecycle classification among running, retrying, quota-waiting, and blocked.
- **FR-002**: The dashboard and JSON status surfaces MUST derive their summary counts and primary listings from the same classification rules.
- **FR-003**: An ordinary operator-input or approval pause MUST be classified as blocked and MUST expose a concise, non-secret reason when one is available.
- **FR-004**: A recoverable quota pause MUST be classified as quota-waiting and MUST expose its non-secret harness, pool, renewal or recheck timing, native-context availability, and stable outcome.
- **FR-005**: A quota pause that cannot resume without operator action MUST be classified as blocked, MUST expose quota context needed for diagnosis, and MUST NOT also appear as a recoverable quota wait.
- **FR-006**: Runtime lifecycle status MUST be visually and semantically distinct from the issue tracker's workflow state; tracker state MAY be supplementary context but MUST NOT label blocked work as running or healthy.
- **FR-007**: Status badges, labels, explanatory copy, counts, and detail fields MUST use consistent terminology for the same lifecycle classification across the dashboard and JSON status surfaces.
- **FR-008**: Status projections MUST handle temporarily overlapping internal records deterministically so one issue is neither double-counted nor presented with conflicting primary states.
- **FR-009**: When an issue resumes, retries, is cancelled, becomes terminal, loses eligibility, or is cleaned up, the next completed snapshot MUST omit obsolete paused classifications.
- **FR-010**: Durable quota-wait reconstruction after restart MUST preserve the classification, diagnostic quota context, and operator-action requirement represented before restart.
- **FR-011**: Dashboard updates MUST refresh the affected count and row from one coherent snapshot without requiring an operator-triggered page reload.
- **FR-012**: Displayed reasons and status context MUST exclude credentials, raw provider payloads, prompts, and other secret or unnecessarily verbose data.
- **FR-013**: Existing behavior for running sessions, retry backoff, aggregate token usage, rate-limit display, and whole-snapshot unavailability MUST remain unchanged except where needed to enforce unique lifecycle classification.

### Key Entities

- **Runtime Status Entry**: The operator-facing projection of one issue, including its unique primary lifecycle classification and optional supplementary tracker state.
- **Blocked Condition**: A pause requiring operator input, approval, or corrective action, with a stable kind, concise reason, timestamp, and available session context.
- **Quota Wait**: A durable quota-related pause with harness, pool, timing, continuation availability, outcome, and a distinction between automatic recovery and operator action.
- **Status Snapshot**: A coherent set of distinct issue projections and counts used by terminal, HTTP, and LiveView observability surfaces.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In validation scenarios covering every supported paused condition, 100% of issues display the expected primary lifecycle status and a reason or next-action cue.
- **SC-002**: For every generated validation snapshot, each issue appears in no more than one primary status group and each summary count equals the number of distinct rows in that group.
- **SC-003**: In transition tests covering block, quota wait, operator-blocked fallback, resume, cancellation, terminal cleanup, and restart, the first completed snapshot after each transition contains no stale or conflicting primary status.
- **SC-004**: Dashboard and JSON validation for the same snapshot produce matching lifecycle classifications and diagnostic context for 100% of represented issues.
- **SC-005**: Existing observability regression suites for running, retrying, token, rate-limit, and unavailable states continue to pass without changed operator meaning.

## Assumptions

- The supported scope is the existing Elixir terminal, HTTP JSON, and LiveView observability surfaces; it does not introduce a new dashboard or persistent store.
- "Blocked" includes any runtime condition requiring operator action, while "quota-waiting" is reserved for quota pauses that still have an automatic renewal or recheck path.
- Tracker workflow state remains useful supplementary context but is not the authoritative runtime lifecycle classification.
- Existing PubSub and snapshot refresh mechanisms remain the delivery path for live updates.
- The feature may normalize projections defensively even if internal state transitions are also tightened; the orchestrator remains the authoritative owner of mutable runtime state.

## Out of Scope

- Changing quota allocation, provider billing, or provider-side renewal behavior.
- Adding new operator commands or automatically reconstructing a missing native Codex session.
- Redesigning unrelated dashboard layout, styling, token accounting, or rate-limit collection.
- Persisting ordinary non-quota blocked sessions across orchestrator restart unless already required by an existing workflow checkpoint contract.
