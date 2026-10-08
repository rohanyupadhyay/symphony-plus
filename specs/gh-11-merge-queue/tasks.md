---

description: "Implementation tasks for the GitHub-backed serialized merge queue"
---

# Tasks: Safely Queue Parallel Pull Requests

**Input**: Design documents from `specs/gh-11-merge-queue/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/merge-queue.md, quickstart.md

**Tests**: Required by the specification, quickstart scenarios, and Constitution V. Each behavioral group starts with a focused failing test.

**Organization**: Tasks are grouped by user story so each increment has an independently observable safety outcome.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish typed queue configuration and reusable GitHub fixture support.

- [X] T001 Add merge-queue configuration fields, defaults, and validation to `elixir/lib/symphony_elixir/config/schema.ex`
- [X] T002 [P] Add valid, disabled, reload, and invalid merge-queue configuration cases to `elixir/test/symphony_elixir/config_test.exs`
- [X] T003 [P] Add deterministic pull-request, review, check, ref, dependency, and merge response fixtures to `elixir/test/support/github_fixtures.ex`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define durable queue records and host-authenticated GitHub operations shared by all stories.

**⚠️ CRITICAL**: No user-story implementation begins until the durable contract and provider operations are covered by failing tests.

- [X] T004 Write failing serialization, validation, identity, and transition tests for queue entries, candidates, dependencies, and outcomes in `elixir/test/symphony_elixir/github_merge_queue_state_test.exs`
- [X] T005 Implement queue entry, integration candidate (`source_head_sha`, `target_sha`, post-update `candidate_sha`), dependency, and outcome types with adjacent public specs in `elixir/lib/symphony_elixir/github/merge_queue/state.ex`
- [X] T006 Write failing client tests for PR/review/check/ref reads, guarded update-branch, expected-head merge, and ambiguous-response reconciliation in `elixir/test/symphony_elixir/github_client_test.exs`
- [X] T007 Implement the typed GitHub merge-queue read and conditional mutation operations in `elixir/lib/symphony_elixir/github/client.ex`
- [X] T008 Write failing versioned checkpoint encoding/decoding tests for admission, candidate, outcome, dependencies, and recovery data in `elixir/test/symphony_elixir/github_workflow_control_test.exs`
- [X] T009 Extend durable workflow-control checkpoint validation and rendering for queue generations and outcomes in `elixir/lib/symphony_elixir/github/workflow_control.ex`

**Checkpoint**: Queue data can round-trip through trusted GitHub-visible state and all remote mutations can be guarded by exact revision evidence.

---

## Phase 3: User Story 1 - Safely merge approved pull requests in sequence (Priority: P1) 🎯 MVP

**Goal**: Admit approved current generations and serialize candidate validation and merge against the latest target for each queue key.

**Independent Test**: Admit three eligible PRs for one target and demonstrate that exactly one candidate is active, each candidate records the target produced by the prior merge, stale evidence never merges, and distinct target-branch keys may advance independently.

### Tests for User Story 1

- [X] T010 [US1] Write failing coordinator tests for stable admission ordering, duplicate admission, one active head per queue key, and independent queue keys in `elixir/test/symphony_elixir/github_merge_queue_test.exs`
- [X] T011 [US1] Write failing current-target tests for guarded update-branch, candidate-check attribution, target movement, eligibility loss, conditional merge, and ambiguous merge reconciliation in `elixir/test/symphony_elixir/github_merge_queue_test.exs`

### Implementation for User Story 1

- [X] T012 [US1] Implement the single supervised queue coordinator, poll scheduling, queue-key ownership, and disabled/reload behavior in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T013 [US1] Implement trusted admission reconstruction, stable ordering by admission sequence then PR number, and idempotent generation handling in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T014 [US1] Implement current-target candidate construction from `source_head_sha`, guarded active-head update, checks on the resulting `candidate_sha`, freshness re-read requiring the PR head to equal `candidate_sha` and target to equal `target_sha`, and merge with `candidate_sha` as expected head in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T015 [US1] Implement idempotent merge-success and ambiguous-response reconciliation before queue advancement in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T016 [US1] Supervise the merge queue once in `elixir/lib/symphony_elixir.ex` and prove restart health with a synchronous observable call in `elixir/test/symphony_elixir/core_test.exs`
- [X] T017 [US1] Change formal approved-review workflow handling to emit durable queue admission instead of direct merge authority in `elixir/lib/symphony_elixir/github/workflow_control.ex` and `elixir/test/symphony_elixir/github_workflow_control_test.exs`

**Checkpoint**: Approved PRs integrate serially against the exact current target without weakening repository policy.

---

## Phase 4: User Story 2 - Recover incompatible pull requests without blocking the queue (Priority: P1)

**Goal**: Remove deterministic incompatibilities from the active path with actionable outcomes while preserving transient failures and allowing independent successors to advance.

**Independent Test**: Make the active head conflict or fail a required candidate check, observe one update-required outcome and successor advancement, then update the failed PR and prove only its new eligible generation re-enters.

### Tests for User Story 2

- [X] T018 [US2] Write failing conflict, deterministic-check-failure, successor-advancement, and new-generation re-entry tests in `elixir/test/symphony_elixir/github_merge_queue_test.exs`
- [X] T019 [US2] Write failing timeout, rate-limit, unknown-mergeability, check-infrastructure, bounded-backoff, and operator-block tests in `elixir/test/symphony_elixir/github_merge_queue_test.exs`

### Implementation for User Story 2

- [X] T020 [US2] Implement deterministic failure classification, update-required outcomes, active-path removal, and independent successor selection in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T021 [US2] Implement new-head invalidation and eligibility-gated re-entry as a distinct queue generation in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T022 [US2] Implement transient failure classification, configured bounded backoff, ambiguous-state holds, and operator recovery outcomes in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T023 [US2] Add stable non-secret queue lifecycle logging with repository, target, PR, originating issue, revisions, outcome, reason, and recovery action in `elixir/lib/symphony_elixir/github/merge_queue.ex`

**Checkpoint**: Code incompatibilities request author updates; infrastructure failures do not, and neither silently deadlocks unrelated entries.

---

## Phase 5: User Story 3 - Preserve parallel work without continuous rebasing (Priority: P2)

**Goal**: Ensure ordinary target movement never rewrites non-head branches and only final integration performs a guarded update.

**Independent Test**: Advance the target with multiple non-head PRs open and prove no non-head branch mutation occurs; then promote one head and prove exactly one expected-head update occurs.

### Tests for User Story 3

- [X] T024 [US3] Write failing tests that target movement performs zero non-head updates and only the active head receives one guarded final-integration update in `elixir/test/symphony_elixir/github_merge_queue_test.exs`

### Implementation for User Story 3

- [X] T025 [US3] Restrict update-branch dispatch to the selected active candidate and invalidate it on concurrent source or target movement in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T026 [US3] Add regression coverage that admission polling and dependency reconciliation are read-only for non-head PR branches in `elixir/test/symphony_elixir/github_merge_queue_test.exs`

**Checkpoint**: Development and review remain parallel without continuous automated branch churn.

---

## Phase 6: User Story 4 - Merge dependent pull requests in declared order (Priority: P2)

**Goal**: Resolve explicit same-repository prerequisite links, hold dependents until prerequisites merge, and surface invalid graphs without blocking independent work.

**Independent Test**: Admit a dependent before its prerequisite, demonstrate prerequisite-first integration and post-prerequisite revalidation, then exercise chains, shared prerequisites, cycles, self-links, missing PRs, cross-repository links, and closed-unmerged prerequisites.

### Tests for User Story 4

- [X] T027 [US4] Write failing prerequisite-first, chain, shared-prerequisite, and post-prerequisite revalidation tests in `elixir/test/symphony_elixir/github_merge_queue_test.exs`
- [X] T028 [US4] Write failing cycle, self-link, duplicate, missing, cross-repository, and closed-unmerged dependency tests in `elixir/test/symphony_elixir/github_merge_queue_test.exs`

### Implementation for User Story 4

- [X] T029 [US4] Parse and normalize durable same-repository prerequisite PR numbers from admission checkpoints in `elixir/lib/symphony_elixir/github/merge_queue/state.ex`
- [X] T030 [US4] Implement dependency graph resolution, cycle detection, prerequisite-first eligibility, and actionable dependency holds in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T031 [US4] Reconstruct dependency status on every selection and force a fresh candidate after all prerequisites merge in `elixir/lib/symphony_elixir/github/merge_queue.ex`

**Checkpoint**: Valid stacks merge in declared order and invalid graphs produce specific durable blockers.

---

## Phase 7: Lifecycle, Documentation, and Cross-Cutting Validation

**Purpose**: Complete constitution-required recovery paths, public contracts, operator guidance, and end-to-end evidence.

- [X] T032 Write failing startup, coordinator restart, repeated-poll, cancellation, PR-closure, approval-dismissal, label-removal, partial-checkpoint-write, and post-merge-response-loss tests in `elixir/test/symphony_elixir/github_merge_queue_test.exs`
- [X] T033 Implement startup reconstruction, repeated-poll idempotency, cancellation/eligibility reconciliation, and partial-failure recovery in `elixir/lib/symphony_elixir/github/merge_queue.ex`
- [X] T034 [P] Update normative serialized-integration and human/repository-policy boundaries in `SPEC.md`
- [X] T035 [P] Document merge-queue configuration, operation, dependency declarations, outcomes, and recovery in `README.md`, `elixir/README.md`, and `elixir/docs/github-merge-queue.md`
- [X] T036 [P] Update the reusable durable workflow instructions and example configuration in `elixir/WORKFLOW.md` and `elixir/examples/github-speckit-WORKFLOW.md`
- [X] T037 Run all eight scenarios from `specs/gh-11-merge-queue/quickstart.md` with focused tests and record any intentional omissions in `specs/gh-11-merge-queue/quickstart.md`
- [X] T038 Run `mix specs.check` and targeted GitHub queue/workflow/client/config tests from `elixir/`, then run `make -C elixir all`
- [X] T039 Review the final repository diff under `.` for secrets, unrelated changes, generated artifacts, unchecked implementation tasks, documentation drift, and constitution violations

## Phase 8: Convergence

- [X] T040 CRITICAL persist candidate and terminal outcome checkpoints through `elixir/lib/symphony_elixir/github/merge_queue/backend.ex` and `elixir/lib/symphony_elixir/github/workflow_control.ex`, with restart reconstruction tests in `elixir/test/symphony_elixir/github_merge_queue_test.exs`, per FR-002, FR-015, FR-017, and SC-007 (missing)
- [X] T041 CRITICAL remove terminal or update-required generations from the active path so independent successors advance, while allowing only a newly eligible head generation to re-enter, in `elixir/lib/symphony_elixir/github/merge_queue.ex` and `elixir/test/symphony_elixir/github_merge_queue_test.exs` per FR-007 through FR-010 and SC-004 (contradicts)
- [X] T042 reconstruct prerequisite states from GitHub on every selection, distinguish merged, queued, missing, cross-repository, closed-unmerged, self, and cyclic dependencies, and test prerequisite-first revalidation in `elixir/lib/symphony_elixir/github/merge_queue/backend.ex`, `elixir/lib/symphony_elixir/github/merge_queue.ex`, and `elixir/test/symphony_elixir/github_merge_queue_test.exs` per FR-012 through FR-014 and SC-006 (partial)
- [X] T043 gate loaded admissions and final merge on current PR state, exact generation head, latest effective reviews, required check runs plus commit statuses, label eligibility, mergeability, and repository policy in `elixir/lib/symphony_elixir/github/merge_queue/backend.ex`, `elixir/lib/symphony_elixir/github/client.ex`, and focused tests per FR-004 through FR-006 and SC-002 through SC-003 (partial)
- [X] T044 reconcile ambiguous update and merge responses by re-reading provider-visible PR, head, target, and merge state before retry or advancement in `elixir/lib/symphony_elixir/github/merge_queue/backend.ex` and `elixir/test/symphony_elixir/github_merge_queue_test.exs` per FR-005, FR-015, FR-018, and SC-007 (missing)
- [X] T045 wire configured bounded retry backoff, operator-block outcomes, and dynamic enabled/interval reload into `elixir/lib/symphony_elixir/github/merge_queue.ex`, with timeout, rate-limit, infrastructure-failure, reload, and restart tests in `elixir/test/symphony_elixir/github_merge_queue_test.exs` per FR-015, FR-018, and Constitution III (partial)
- [X] T046 add observable lifecycle and recovery coverage for startup reconstruction, coordinator restart, repeated polls, cancellation, PR closure, approval dismissal, label removal, source/target movement, partial checkpoint writes, and lost merge responses in `elixir/test/symphony_elixir/github_merge_queue_test.exs` per SC-008 and Constitution III/V (missing)
- [X] T047 expose durable queue position, blocker, validation outcome, and recovery action through GitHub-visible checkpoint comments and stable non-secret logs containing repository, target, PR, originating issue, revisions, outcome, reason, and recovery in `elixir/lib/symphony_elixir/github/merge_queue/backend.ex` and focused tests per FR-019 and Constitution VI (partial)
- [X] T048 allow same-repository managed PRs when their containing repository is itself a fork, expose guarded `merge_queued` admissions through the host checkpoint tool, and enable approval-driven queueing in `.symphony/WORKFLOW.md`, with focused workflow-control and adapter regressions
- [X] T049 normalize non-queue and malformed latest checkpoints to empty admission lists in `elixir/lib/symphony_elixir/github/merge_queue/backend.ex`, with a production-shape loader regression and live enabled-queue restart verification

## Phase 9: Dependency Advancement Revision

- [X] T050 [US4] Add coordinator regressions proving the selected prerequisite generation—not the dependent queue prefix—is advanced and tracked in `elixir/test/symphony_elixir/github_merge_queue_test.exs`
- [X] T051 [US4] Persist actionable dependency blockers for missing, cross-repository, closed-unmerged, self, and cyclic relationships without blocking independent entries in `elixir/lib/symphony_elixir/github/merge_queue.ex`, `elixir/lib/symphony_elixir/github/merge_queue/backend.ex`, and focused tests
- [X] T052 [US4] Run the dependency stack end-to-end through loader resolution, coordinator selection, and durable outcome execution, then complete a fresh Spec Kit requirement audit and full validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 and blocks all user stories.
- **US1 (Phase 3)**: Depends on Phase 2 and establishes the MVP queue owner and current-target merge path.
- **US2 (Phase 4)**: Depends on US1 candidate selection and outcomes.
- **US3 (Phase 5)**: Depends on US1 active-head selection; it is independently testable after US1.
- **US4 (Phase 6)**: Depends on foundational durable dependencies and US1 selection; it may proceed in parallel with US2/US3 after US1.
- **Lifecycle/Docs (Phase 7)**: Depends on all selected stories.

### User Story Dependencies

- **US1 (P1)**: No story dependency; MVP after the foundation.
- **US2 (P1)**: Uses US1 candidate/outcome machinery but remains independently testable through failure and re-entry.
- **US3 (P2)**: Uses US1 head selection; adds a negative branch-mutation guarantee.
- **US4 (P2)**: Uses US1 selection and can be developed alongside US2/US3 once US1 is stable.

### Parallel Opportunities

- T002 and T003 touch different test support/config files and can proceed in parallel after T001's schema shape is agreed.
- Documentation tasks T034–T036 touch distinct contracts and can proceed in parallel after behavior stabilizes.
- US2, US3, and US4 test design can proceed in parallel after US1 establishes coordinator interfaces, but edits to `github_merge_queue_test.exs` must be serialized.
- All implementation changes to `merge_queue.ex` are sequential to preserve one clear state owner.

---

## Parallel Example: User Story 4 and Documentation

```text
Task: "Design dependency graph cases in elixir/test/symphony_elixir/github_merge_queue_test.exs"
Task: "Update normative serialized integration contract in SPEC.md"
Task: "Document operator configuration and recovery in elixir/docs/github-merge-queue.md"
```

---

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases.
2. Complete US1 with red-green-refactor evidence.
3. Validate sequential current-target integration and stale-candidate rejection independently.
4. Add failure recovery, non-head stability, and dependency ordering incrementally.

### Test and Commit Discipline

1. Write and run the focused failing test named by each behavioral task.
2. Implement the smallest coherent change under the single coordinator owner.
3. Run the focused test group and mark the task complete only after it passes.
4. Run targeted integration checks after each story and `make -C elixir all` at handoff.

## Notes

- `[P]` means distinct files and no dependency on an incomplete task.
- `[USn]` maps directly to the numbered user story in `spec.md`.
- Custom checklist markers remain reviewer-owned and are never changed by implementation.
- Public `def` functions in `elixir/lib/` require adjacent `@spec` declarations unless they are `@impl` callbacks.
