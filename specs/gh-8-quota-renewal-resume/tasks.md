# Tasks: Quota-Aware Harness Resume

**Input**: Design documents from `specs/gh-8-quota-renewal-resume/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required by the specification and constitution. Write each focused test task first, observe it fail, then complete its paired implementation task.

**Organization**: Tasks are grouped by user story so quota pausing, native-context resume, and operator recovery remain independently demonstrable increments.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it affects different files and has no incomplete dependency
- **[Story]**: Maps the task to a user story in spec.md
- Every task names the exact file or files it changes

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish configuration and reusable test inputs without changing runtime behavior.

- [X] T001 Add quota configuration validation tests for positive `quota.unknown_recheck_ms` and the 300,000 ms default in `elixir/test/symphony_elixir/workspace_and_config_test.exs`
- [X] T002 Implement the typed quota recheck configuration and schema validation in `elixir/lib/symphony_elixir/config.ex` and `elixir/lib/symphony_elixir/config/schema.ex`
- [X] T003 [P] Add pinned recognized-quota, lookalike-error, renewal-time, and native-thread fixtures in `elixir/test/support/fixtures/codex_app_server/`

**Checkpoint**: Configuration is typed and deterministic fixtures are available for red/green work.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the shared harness-neutral contract and validated durable store used by every story.

**⚠️ CRITICAL**: No user-story implementation begins until this phase is complete.

- [X] T004 Add failing contract tests for normalized quota signals, pool keys, renewal validation, continuation references, and secret-field rejection in `elixir/test/symphony_elixir/harness_quota_test.exs`
- [X] T005 Implement `QuotaSignal` and `ContinuationReference` value contracts with `harness` required as `codex`, `pool_key` required stable/non-empty/bounded/non-secret, and continuation `native_id`, `issue_id`, and `workspace_key` required in `elixir/lib/symphony_elixir/harness/quota.ex`
- [X] T006 Add failing store tests for version `1`, required quota-wait fields, enum states `waiting|eligible|resuming|operator_blocked`, allowlisted JSON, atomic replacement, invalid filenames/workspace roots, corrupt records, and unknown versions in `elixir/test/symphony_elixir/quota_wait_store_test.exs`
- [X] T007 Implement validated issue-scoped atomic quota-wait persistence under `<workspace-root>/.symphony/quota-waits/` in `elixir/lib/symphony_elixir/quota_wait_store.ex`
- [X] T008 Run `cd elixir && mix test test/symphony_elixir/harness_quota_test.exs test/symphony_elixir/quota_wait_store_test.exs test/symphony_elixir/workspace_and_config_test.exs` and resolve foundational regressions in the files changed by T001–T007

**Checkpoint**: Shared contracts and durable records satisfy the schema and workspace/secret boundaries.

---

## Phase 3: User Story 1 - Pause Work at Quota Exhaustion (Priority: P1) 🎯 MVP

**Goal**: Recognize Codex quota exhaustion, durably pause affected work, release its slot, and suppress only the exhausted quota pool.

**Independent Test**: A deterministic Codex quota signal moves one running issue to a durable wait, frees its slot without incrementing failure retry, suppresses same-pool dispatch, and leaves unrelated pools eligible.

### Tests for User Story 1

- [X] T009 [P] [US1] Add failing Codex classification tests proving only pinned quota/rate-limit signals normalize and transport, auth, permission, billing, and free-text lookalikes retain existing error outcomes in `elixir/test/symphony_elixir/app_server_test.exs`
- [X] T010 [P] [US1] Add failing orchestrator lifecycle tests for persist-before-release, slot release, no retry increment, same-pool suppression, unrelated-pool dispatch, duplicate signals, repeated polls, and persistence failure in `elixir/test/symphony_elixir/orchestrator_status_test.exs`

### Implementation for User Story 1

- [X] T011 [US1] Normalize recognized Codex quota outcomes with validated future renewal or unknown-renewal recheck data while excluding raw provider payloads in `elixir/lib/symphony_elixir/codex/app_server.ex`
- [X] T012 [US1] Return normalized quota outcomes and captured native thread identity through the runner boundary in `elixir/lib/symphony_elixir/agent_runner.ex`
- [X] T013 [US1] Add authoritative quota-wait and exhausted-pool indexes, persist-before-release transitions, slot accounting, pool-aware dispatch eligibility, and duplicate-signal idempotence in `elixir/lib/symphony_elixir/orchestrator.ex`
- [X] T014 [US1] Run `cd elixir && mix test test/symphony_elixir/app_server_test.exs test/symphony_elixir/orchestrator_status_test.exs test/symphony_elixir/quota_wait_store_test.exs` and resolve User Story 1 regressions in files changed by T009–T013

**Checkpoint**: User Story 1 independently provides safe quota pausing and pool-scoped suppression.

---

## Phase 4: User Story 2 - Resume with Prior Context (Priority: P2)

**Goal**: Recover eligible quota waits and resume exactly one preserved Codex thread without a fresh-conversation fallback.

**Independent Test**: After renewal or restart, one still-eligible issue atomically reserves resume, calls `thread/resume`, reuses its workspace, and starts one continuation turn; missing or mismatched native context blocks safely.

### Tests for User Story 2

- [X] T015 [P] [US2] Add failing app-server tests for `thread/resume`, issue/workspace identity validation, continuation turn startup, unavailable thread handling, and the prohibition on `thread/start` fallback in `elixir/test/symphony_elixir/app_server_test.exs`
- [X] T016 [P] [US2] Add failing orchestrator tests for restart reload/reconciliation, no pre-renewal launch, bounded unknown-renewal recheck, atomic `resuming` reservation, simultaneous eligibility, stale monitor messages, second exhaustion, and at-most-one active run in `elixir/test/symphony_elixir/orchestrator_status_test.exs`

### Implementation for User Story 2

- [X] T017 [US2] Implement validated native Codex `thread/resume` followed by a continuation turn and return operator-blocked outcomes for unavailable or mismatched threads in `elixir/lib/symphony_elixir/codex/app_server.ex`
- [X] T018 [US2] Pass quota-resume run metadata, preserved workspace, continuation reference, and remaining-work guidance through `elixir/lib/symphony_elixir/agent_runner.ex`
- [X] T019 [US2] Load and reconcile durable waits on startup, enforce renewal/recheck eligibility, persist the `resuming` reservation before launch, handle repeated exhaustion, and block failed native resumes without ordinary retry in `elixir/lib/symphony_elixir/orchestrator.ex`
- [X] T020 [US2] Run `cd elixir && mix test test/symphony_elixir/app_server_test.exs test/symphony_elixir/orchestrator_status_test.exs test/symphony_elixir/quota_wait_store_test.exs` and resolve User Story 2 regressions in files changed by T015–T019

**Checkpoint**: User Stories 1 and 2 independently prove durable pause and native-context continuation.

---

## Phase 5: User Story 3 - Understand and Recover Quota Waits (Priority: P3)

**Goal**: Make quota lifecycle state observable and keep cancellation, cleanup, reload, and operator-block paths safe.

**Independent Test**: Status and logs distinguish waiting, retrying, resuming, and operator-blocked work; reconciliation removes or retains state correctly; no secret or raw provider payload appears.

### Tests for User Story 3

- [X] T021 [P] [US3] Add failing orchestrator tests for cancellation, terminal transition, label/dispatchability loss, dynamic concurrency and recheck reload, workspace loss, corrupt state, and terminal cleanup in `elixir/test/symphony_elixir/orchestrator_status_test.exs`
- [X] T022 [P] [US3] Add failing status and secret-filtering assertions for waiting/resuming/operator-blocked state, renewal availability, native-context availability, issue/session context, and stable outcomes in `elixir/test/symphony_elixir/status_dashboard_snapshot_test.exs`

### Implementation for User Story 3

- [X] T023 [US3] Integrate quota waits with reconciliation, cancellation, terminal cleanup, label/dispatchability changes, workspace validation, and future-decision config reload in `elixir/lib/symphony_elixir/orchestrator.ex`
- [X] T024 [P] [US3] Expose quota waiting, resuming, and operator-blocked fields without raw payloads in `elixir/lib/symphony_elixir/status_dashboard.ex` and `elixir/lib/symphony_elixir_web/presenter.ex`
- [X] T025 [US3] Render quota lifecycle state and native-continuation availability in `elixir/lib/symphony_elixir_web/live/dashboard_live.ex`
- [X] T026 [US3] Add stable quota lifecycle logs with applicable issue, session, harness, pool, renewal, decision, outcome, and concise reason fields in `elixir/lib/symphony_elixir/orchestrator.ex`, `elixir/lib/symphony_elixir/agent_runner.ex`, and `elixir/lib/symphony_elixir/codex/app_server.ex`
- [X] T027 [US3] Run `cd elixir && mix test test/symphony_elixir/orchestrator_status_test.exs test/symphony_elixir/status_dashboard_snapshot_test.exs test/symphony_elixir/app_server_test.exs` and resolve User Story 3 regressions in files changed by T021–T026

**Checkpoint**: All three user stories are independently observable and lifecycle-safe.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Align normative and operator documentation, execute adversarial lifecycle review, and complete repository gates.

- [X] T028 [P] Update normative quota waiting and native-resume behavior in `SPEC.md`
- [X] T029 [P] Update feature overview and operator expectations in `README.md` and configuration/run guidance in `elixir/README.md`
- [X] T030 [P] Document quota signal mapping, pool scope, renewal/recheck, persistence, native-resume, and operator-block recovery in `elixir/docs/quota-resume.md`, and update required fields in `elixir/docs/logging.md`
- [X] T031 Perform adversarial review of duplicate dispatch, restart/reconciliation, cancellation/cleanup, stale messages, pool isolation, persistence failure, secret leakage, and fresh-thread fallback; add any reproducing tests to `elixir/test/symphony_elixir/` and fixes to the corresponding `elixir/lib/` modules
- [X] T032 Run the focused quickstart suite from `specs/gh-8-quota-renewal-resume/quickstart.md` and `cd elixir && mix specs.check`, resolving failures in scoped files
- [X] T033 Run `make -C elixir all` and review the complete diff for secrets, raw provider payloads, unrelated changes, generated artifacts, public functions without adjacent `@spec`, incomplete tasks, documentation gaps, and constitution violations

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational and is the MVP
- **User Story 2 (Phase 4)**: Depends on the wait/store and runner boundaries established by User Story 1
- **User Story 3 (Phase 5)**: Depends on the lifecycle states established by User Stories 1 and 2
- **Polish (Phase 6)**: Depends on all selected user stories

### Within Each User Story

- Test tasks MUST be written and observed failing before paired implementation
- Provider normalization and runner plumbing precede orchestrator transitions
- Orchestrator state precedes status presentation and documentation
- The phase-specific targeted test task closes each story

### Parallel Opportunities

- T003 can proceed independently of T001–T002
- T009 and T010 can be authored in parallel before T011–T013
- T015 and T016 can be authored in parallel before T017–T019
- T021 and T022 can be authored in parallel; T024 can proceed after the status shape is established
- T028, T029, and T030 can proceed in parallel after behavior stabilizes

---

## Parallel Example: User Story 1

```text
Task T009: Codex quota classification tests in elixir/test/symphony_elixir/app_server_test.exs
Task T010: Orchestrator quota-wait lifecycle tests in elixir/test/symphony_elixir/orchestrator_status_test.exs
```

## Parallel Example: User Story 3

```text
Task T021: Reconciliation and cleanup tests in elixir/test/symphony_elixir/orchestrator_status_test.exs
Task T022: Status and secret-filtering assertions in elixir/test/symphony_elixir/status_dashboard_snapshot_test.exs
```

---

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases.
2. Complete User Story 1 with red/green evidence.
3. Stop and validate durable pausing, slot release, and pool-scoped suppression independently.

### Incremental Delivery

1. Add User Story 2 and prove native-context resume plus restart idempotence.
2. Add User Story 3 and prove lifecycle reconciliation, observability, and secret safety.
3. Complete documentation, adversarial review, targeted validation, and the full gate.

## Notes

- `[P]` tasks affect separate files or independent test surfaces
- `[US1]`, `[US2]`, and `[US3]` preserve requirement-to-story traceability
- Mark a task `[X]` only after its implementation and stated validation are complete
- Custom checklist markers remain reviewer-owned and are never changed by implementation
- Stop on a reproducible adjacent lifecycle failure even if the primary path passes
