# Tasks: Accurate Blocked Session Status

**Input**: Design documents from `specs/gh-17-accurate-blocked-status/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required by the approved plan and Constitution Principle V. Write each story's focused tests first and observe the intended failure before implementation.

**Organization**: Tasks are grouped by user story so each operator-visible increment can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it affects different files and does not depend on incomplete work
- **[Story]**: Maps the task to its feature-spec user story
- Every task names the exact file it changes

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the existing project boundaries and establish the shared test/module locations without adding dependencies.

- [ ] T001 Verify existing ignore rules and Elixir project configuration need no feature-specific additions in `.gitignore` and `elixir/mix.exs`
- [ ] T002 Create the pure projection module skeleton with public type/function specs in `elixir/lib/symphony_elixir/runtime_status.ex`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the authoritative normalized read-model contract used by every user story.

**⚠️ CRITICAL**: No renderer or lifecycle integration may begin until the projection invariant is covered by a failing test and implemented.

- [ ] T003 Add failing unit tests for identity deduplication, precedence `blocked > quota_waiting > retrying > running`, and count/list partition equality in `elixir/test/symphony_elixir/runtime_status_test.exs`
- [ ] T004 Implement normalized runtime entries, deterministic identity merging, primary lists, and derived counts in `elixir/lib/symphony_elixir/runtime_status.ex`
- [ ] T005 Add failing unit tests that reasons are one line and at most 160 Unicode graphemes including any truncation marker, missing blocked reasons project as `Operator action required`, missing quota timing projects as `Renewal time unavailable`, control characters are removed, and quota `operator_blocked` context is retained in `elixir/test/symphony_elixir/runtime_status_test.exs`
- [ ] T006 Implement the exact T005 reason/timing constraints and secret-safe quota-context projection without raw payload or prompt fields in `elixir/lib/symphony_elixir/runtime_status.ex`
- [ ] T007 Run `mix test test/symphony_elixir/runtime_status_test.exs` from `elixir/` and record the focused foundational result in `specs/gh-17-accurate-blocked-status/tasks.md`

**Checkpoint**: One pure, tested projection owns lifecycle classification and safety rules.

---

## Phase 3: User Story 1 - Identify Paused Work Accurately (Priority: P1) 🎯 MVP

**Goal**: Show one accurate paused classification, reason, next-action cue, and safe context for ordinary blocks and quota conditions.

**Independent Test**: Snapshots containing an ordinary block, renewable quota wait, and unrecoverable quota-resume block each expose one expected primary status and matching diagnostic context.

### Tests for User Story 1

- [ ] T008 [US1] Add failing orchestrator snapshot tests for ordinary blocked, recoverable quota, and quota-derived operator-blocked records in `elixir/test/symphony_elixir/orchestrator_status_test.exs`
- [ ] T009 [P] [US1] Add failing terminal snapshot assertions for distinct blocked and quota-waiting sections and concise reasons in `elixir/test/symphony_elixir/status_dashboard_snapshot_test.exs`
- [ ] T010 [P] [US1] Add failing JSON presenter assertions for primary status, supplementary tracker state, and safe diagnostic fields in `elixir/test/symphony_elixir/extensions_test.exs`

### Implementation for User Story 1

- [ ] T011 [US1] Route `handle_call(:snapshot)` raw running/retrying/blocked/quota records through `SymphonyElixir.RuntimeStatus` in `elixir/lib/symphony_elixir/orchestrator.ex`
- [ ] T012 [P] [US1] Render blocked and recoverable quota entries with shared lifecycle terminology in `elixir/lib/symphony_elixir/status_dashboard.ex`
- [ ] T013 [P] [US1] Serialize normalized state and issue-detail entries without incompatible simultaneous primary objects in `elixir/lib/symphony_elixir_web/presenter.ex`
- [ ] T014 [P] [US1] Render normalized blocked/quota status, reason, next action, and supplementary tracker state in `elixir/lib/symphony_elixir_web/live/dashboard_live.ex`
- [ ] T015 [US1] Run the US1 focused test files from `elixir/` and record results in `specs/gh-17-accurate-blocked-status/tasks.md`

**Checkpoint**: An operator can distinguish intervention-required blocks from automatically recoverable quota waits on every surface.

---

## Phase 4: User Story 2 - Trust Dashboard Counts (Priority: P2)

**Goal**: Ensure summaries and tables count each issue exactly once under its primary classification.

**Independent Test**: A deliberately overlapping mixed snapshot produces count values equal to distinct rows in each mutually exclusive primary group.

### Tests for User Story 2

- [ ] T016 [P] [US2] Add failing presenter and API assertions that counts equal normalized array lengths under overlapping raw records in `elixir/test/symphony_elixir/extensions_test.exs`
- [ ] T017 [P] [US2] Add failing terminal assertions that overlapping records produce one row in only the highest-precedence section in `elixir/test/symphony_elixir/status_dashboard_snapshot_test.exs`

### Implementation for User Story 2

- [ ] T018 [US2] Consume projection-derived counts and lists rather than raw collection lengths in `elixir/lib/symphony_elixir_web/presenter.ex`
- [ ] T019 [US2] Consume the same projection-derived lists for terminal summary and table output in `elixir/lib/symphony_elixir/status_dashboard.ex`
- [ ] T020 [US2] Run the US2 focused test files from `elixir/` and record results in `specs/gh-17-accurate-blocked-status/tasks.md`

**Checkpoint**: Counts, primary arrays, and terminal rows describe the same distinct issue inventory.

---

## Phase 5: User Story 3 - Preserve Accurate Status Through Transitions (Priority: P3)

**Goal**: Keep normalized status coherent through recovery, cancellation, cleanup, restart reconstruction, and live refresh.

**Independent Test**: Lifecycle and restart scenarios leave no stale or duplicate classification in the first completed snapshot, and LiveView updates without manual reload.

### Tests for User Story 3

- [ ] T021 [US3] Add failing real-orchestrator tests for block release, quota resume/fallback, retry, cancellation, terminal cleanup, eligibility loss, and durable quota reconstruction in `elixir/test/symphony_elixir/orchestrator_status_test.exs`
- [ ] T022 [P] [US3] Add failing LiveView PubSub refresh and whole-snapshot unavailable-state regression tests in `elixir/test/symphony_elixir/extensions_test.exs`

### Implementation for User Story 3

- [ ] T023 [US3] Apply the normalized read projection after existing lifecycle mutation and quota-restart reconstruction paths so the next completed snapshot omits obsolete classifications without introducing a second state owner in `elixir/lib/symphony_elixir/orchestrator.ex`
- [ ] T024 [US3] Ensure one PubSub-triggered reload replaces LiveView counts and rows from the same normalized payload in `elixir/lib/symphony_elixir_web/live/dashboard_live.ex`
- [ ] T025 [US3] Run the US3 focused test files from `elixir/` and record results in `specs/gh-17-accurate-blocked-status/tasks.md`

**Checkpoint**: Transition, restart, and refresh paths preserve a single current lifecycle truth.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Align normative/operator documentation and complete adversarial and repository-wide validation.

- [ ] T026 [P] Document unique runtime classification and blocked/quota-waiting surface semantics in `SPEC.md`
- [ ] T027 [P] Document operator-visible blocked and quota-waiting dashboard behavior in `README.md` and `elixir/README.md`
- [ ] T028 [P] Align quota recovery terminology and operator-action outcomes in `elixir/docs/quota-resume.md`
- [ ] T029 Perform adversarial review of overlap precedence, lifecycle cleanup, restart, partial failure, secret-safe reasons, and unrelated status regressions; record findings and corrections in `specs/gh-17-accurate-blocked-status/tasks.md`
- [ ] T030 Run all quickstart focused commands and `make -C elixir all`, then record results and any omissions in `specs/gh-17-accurate-blocked-status/tasks.md`
- [ ] T031 Review the final diff for secrets, raw provider payloads, unrelated changes, generated artifacts, incomplete tasks, and constitution/documentation violations; record the result in `specs/gh-17-accurate-blocked-status/tasks.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on Setup and blocks all stories.
- **User Story 1 (Phase 3)**: Depends on Foundational and is the MVP.
- **User Story 2 (Phase 4)**: Depends on the shared projection and US1 surface wiring.
- **User Story 3 (Phase 5)**: Depends on the shared projection; follow US1/US2 so transition assertions cover final surface behavior.
- **Polish (Phase 6)**: Depends on all selected stories.

### User Story Dependencies

- **US1**: No dependency beyond Phase 2.
- **US2**: Uses the US1 normalized surface wiring but remains independently testable with overlap snapshots.
- **US3**: Uses the normalized projection and final surfaces but remains independently testable through lifecycle transitions.

### Within Each User Story

- Add and observe failing focused tests before implementation.
- Complete shared projection changes before renderer changes.
- Run the story's focused tests before advancing.
- Changes to the same file run sequentially even when adjacent test tasks are parallelizable.

### Parallel Opportunities

- T009 and T010 can proceed in parallel after T008 establishes snapshot shape.
- T012, T013, and T014 affect separate renderer files and can proceed in parallel after T011.
- T016 and T017 can proceed in parallel; T018 and T019 then affect separate surfaces.
- T021 and T022 can proceed in parallel.
- T026, T027, and T028 update separate documentation files and can proceed in parallel.

---

## Parallel Example: User Story 1

```text
Task T009: Add terminal blocked/quota assertions in elixir/test/symphony_elixir/status_dashboard_snapshot_test.exs
Task T010: Add JSON presenter assertions in elixir/test/symphony_elixir/extensions_test.exs

After T011:
Task T012: Update elixir/lib/symphony_elixir/status_dashboard.ex
Task T013: Update elixir/lib/symphony_elixir_web/presenter.ex
Task T014: Update elixir/lib/symphony_elixir_web/live/dashboard_live.ex
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup and Foundational tasks.
2. Complete US1 tests and surface integration.
3. Run the US1 focused suite and inspect all three surfaces.
4. Stop and validate the independently useful paused-status behavior.

### Incremental Delivery

1. Establish the unique normalized projection.
2. Deliver accurate paused classification and diagnostics (US1).
3. Enforce trustworthy summaries under overlap (US2).
4. Prove transitions, restart, and live refresh (US3).
5. Align documentation, run adversarial review, and pass the full gate.

## Notes

- `[P]` tasks operate on different files and have no incomplete dependency.
- Every completed task must be marked `[X]` by `$speckit-implement`.
- Custom checklist markers remain reviewer-owned and must not be changed during implementation.
- Record red/green evidence and validation outcomes directly beneath the relevant task when executed.
