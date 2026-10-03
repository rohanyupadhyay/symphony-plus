---

description: "Implementation tasks for automatic review of Symphony-created pull requests"
---

# Tasks: Automatically Review Symphony Pull Requests

**Input**: Design documents from `specs/gh-15-auto-review-pr/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/managed-pr-review.md, quickstart.md

**Tests**: Required by the feature specification and Constitution Principle V. Test tasks precede implementation and must fail for the intended reason before production changes.

**Organization**: Tasks are grouped by user story so each increment has an independent validation path.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the existing workflow-control extension points and test fixtures before changing behavior.

- [ ] T001 Map the current checkpoint state validation, trigger derivation, and review-cursor fixtures to the `review_pending` contract in `elixir/lib/symphony_elixir/github/workflow_control.ex` and `elixir/test/symphony_elixir/github_workflow_control_test.exs`
- [ ] T002 [P] Map current PR creation/label/checkpoint handoff behavior and reusable request fixtures in `elixir/lib/symphony_elixir/github/agent_tool.ex` and `elixir/test/symphony_elixir/github_adapter_test.exs`
- [ ] T003 [P] Map current GitHub PR enrichment and pagination fixtures in `elixir/lib/symphony_elixir/github/client.ex` and `elixir/test/symphony_elixir/github_adapter_test.exs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish durable checkpoint and validation primitives shared by every story.

- [ ] T004 Add failing checkpoint-schema tests for `state=review_pending`, `phase=review`, positive `pr_number`, exact issue branch, and 40-character `head_sha` in `elixir/test/symphony_elixir/github_workflow_control_test.exs` and `elixir/test/symphony_elixir/github_adapter_test.exs`
- [ ] T005 Implement `review_pending` checkpoint validation and guidance without weakening existing approval or review states in `elixir/lib/symphony_elixir/github/workflow_control.ex` and `elixir/lib/symphony_elixir/github/agent_tool.ex`
- [ ] T006 Add stable issue/PR-context logging assertions for review handoff, dispatch, suppression, and enrichment failure in `elixir/test/symphony_elixir/github_adapter_test.exs`

**Checkpoint**: Durable review-pending checkpoint data can be validated before user-story behavior is enabled.

---

## Phase 3: User Story 1 - Automatically begin pull request review (Priority: P1) 🎯 MVP

**Goal**: Label the eligible managed PR, durably hand it off, and dispatch exactly one automatic review using the originating issue worker.

**Independent Test**: Create an eligible managed PR, observe label-before-checkpoint ordering and one automatic trigger on the next poll, then repeat polling and reconstruct after restart without a concurrent duplicate.

### Tests for User Story 1

- [ ] T007 [P] [US1] Add failing trigger tests for one unconsumed `review_pending` automatic dispatch, later-checkpoint consumption, and duplicate suppression in `elixir/test/symphony_elixir/github_workflow_control_test.exs`
- [ ] T008 [P] [US1] Add failing adapter tests for label-before-checkpoint ordering, idempotent relabeling, and partial label/checkpoint failures in `elixir/test/symphony_elixir/github_adapter_test.exs`
- [ ] T009 [P] [US1] Add failing launcher tests proving the originating issue remains the sole workspace/worker identity during automatic review in `elixir/test/symphony_elixir/github_launcher_test.exs`

### Implementation for User Story 1

- [ ] T010 [US1] Derive the automatic review trigger once from a valid unconsumed `review_pending` checkpoint and suppress ineligible or terminal states in `elixir/lib/symphony_elixir/github/workflow_control.ex`
- [ ] T011 [US1] Apply the configured `symphony` label idempotently before posting the managed-PR `review_pending` checkpoint in `elixir/lib/symphony_elixir/github/agent_tool.ex`
- [ ] T012 [US1] Preserve originating-issue scheduling, claim, session, and workspace identity for the automatic review turn in `elixir/lib/symphony_elixir/github/client.ex`
- [ ] T013 [US1] Run focused US1 tests and record evidence for label inheritance, next-poll dispatch, restart recovery, and duplicate suppression in `specs/gh-15-auto-review-pr/quickstart.md`

**Checkpoint**: User Story 1 is independently functional and provides the automatic handoff MVP.

---

## Phase 4: User Story 2 - Repair review and validation failures (Priority: P1)

**Goal**: Supply complete current-head review evidence so the automatic pass can diagnose, safely repair, validate, or block.

**Independent Test**: Enrich an eligible review with paginated conversation, reviews, inline comments, merge state, and current-head checks; demonstrate failed retrieval blocks dispatch and stale-head evidence is excluded.

### Tests for User Story 2

- [ ] T014 [P] [US2] Add failing adapter tests for `review_pending` PR metadata, paginated conversation/reviews/inline comments, merge state, and current-head check enrichment in `elixir/test/symphony_elixir/github_adapter_test.exs`
- [ ] T015 [US2] Add failing adapter tests for pending, failed, errored, cancelled, skipped, and passing checks plus stale-head exclusion and required-context retrieval failure in `elixir/test/symphony_elixir/github_adapter_test.exs` after T014 establishes the shared review-context fixtures
- [ ] T016 [P] [US2] Add failing workflow tests for label removal, issue closure, PR closure/merge, fork/cross-repository heads, and managed-identity mismatch in `elixir/test/symphony_elixir/github_workflow_control_test.exs`

### Implementation for User Story 2

- [ ] T017 [US2] Enrich both `review_pending` and `awaiting_review` with complete paginated PR review context and current-head checks in `elixir/lib/symphony_elixir/github/client.ex`
- [ ] T018 [US2] Block automatic dispatch on incomplete required context and suppress work for removed labels, closed issues, terminal PRs, forks, cross-repository heads, or identity mismatch in `elixir/lib/symphony_elixir/github/client.ex` and `elixir/lib/symphony_elixir/github/workflow_control.ex`
- [ ] T019 [US2] Encode the evidence-driven review, safe-repair, check-diagnosis, targeted-test, full-gate, and blocker procedure in `elixir/examples/github-speckit-WORKFLOW.md`
- [ ] T020 [US2] Run focused US2 tests and record evidence for complete context, check classification inputs, stale evidence rejection, and failure handling in `specs/gh-15-auto-review-pr/quickstart.md`

**Checkpoint**: User Story 2 exposes complete trustworthy evidence and bounded repair policy without creating a second writer.

---

## Phase 5: User Story 3 - Hand off a review-ready pull request (Priority: P2)

**Goal**: Produce a durable human-review handoff that accounts for evidence and processes only later new events.

**Independent Test**: Complete an automatic pass into `awaiting_review`, verify fresh cursors prevent replay, and prove later requested changes or checks resume the same branch while approval still waits for human merge.

### Tests for User Story 3

- [ ] T021 [P] [US3] Add failing workflow-control tests for `review_pending` to `awaiting_review`, fresh event cursors, later requested changes/new checks, and old-event replay suppression in `elixir/test/symphony_elixir/github_workflow_control_test.exs`
- [ ] T022 [P] [US3] Add failing agent-tool tests for review-ready and blocked summaries containing findings, corrections, targeted/full validation, check status, omissions, and human action in `elixir/test/symphony_elixir/github_adapter_test.exs`

### Implementation for User Story 3

- [ ] T023 [US3] Preserve fresh review cursors and existing formal review/revision semantics when replacing `review_pending` with `awaiting_review` or `blocked` in `elixir/lib/symphony_elixir/github/agent_tool.ex` and `elixir/lib/symphony_elixir/github/workflow_control.ex`
- [ ] T024 [US3] Document the operator-visible handoff, blocker recovery, later-event resumption, and mandatory human-merge boundary in `elixir/docs/github-workflow-control.md`
- [ ] T025 [US3] Run focused US3 tests and record evidence for handoff, cursor freshness, later feedback, blocked recovery, and no autonomous merge in `specs/gh-15-auto-review-pr/quickstart.md`

**Checkpoint**: All stories are independently testable and the PR waits for human review.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Align product/operator contracts and execute the complete quality gate.

- [ ] T026 [P] Update automatic managed-PR eligibility, label inheritance, durable ownership/recovery, repair scope, and human handoff in `SPEC.md`
- [ ] T027 [P] Update user-facing automatic PR review behavior and configuration guidance in `README.md` and `elixir/README.md`
- [ ] T028 Validate every scenario in `specs/gh-15-auto-review-pr/quickstart.md` and reconcile any documentation drift across `specs/gh-15-auto-review-pr/spec.md`, `specs/gh-15-auto-review-pr/plan.md`, and `specs/gh-15-auto-review-pr/contracts/managed-pr-review.md`
- [ ] T029 Run `make -C elixir all`, review the final diff for secrets, unrelated/generated changes, incomplete tasks, constitution violations, and documentation omissions, and record results in `specs/gh-15-auto-review-pr/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on Setup and blocks all stories.
- **User Story 1 (Phase 3)**: Depends on Foundational and establishes the MVP handoff.
- **User Story 2 (Phase 4)**: Depends on User Story 1 checkpoint identity and dispatch behavior.
- **User Story 3 (Phase 5)**: Depends on User Stories 1 and 2 so handoff cursors summarize a complete pass.
- **Polish (Phase 6)**: Depends on all selected stories.

### Within Each User Story

- Test tasks must be written and fail for the intended reason before implementation.
- State validation precedes trigger derivation; trigger derivation precedes scheduling assertions.
- Context enrichment precedes policy-guidance and end-to-end validation.
- Targeted tests precede the full `make -C elixir all` gate.

### Parallel Opportunities

- T002 and T003 can run in parallel after T001 begins because they inspect different boundaries.
- T007, T008, and T009 can be authored in parallel in separate test files after Phase 2.
- T014 and T016 can be authored in parallel; T015 follows T014 because both modify the shared adapter test fixtures.
- T021 and T022 can run in parallel in separate conceptual fixture groups.
- T026 and T027 can run in parallel because they update distinct documentation files.

---

## Parallel Example: User Story 1

```text
Task T007: Add `review_pending` trigger and duplicate-suppression tests in github_workflow_control_test.exs
Task T008: Add label/checkpoint ordering and retry tests in github_adapter_test.exs
Task T009: Add single originating-issue worker tests in github_launcher_test.exs
```

---

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases.
2. Complete User Story 1 with red-green-refactor evidence.
3. Validate label inheritance, automatic next-poll dispatch, restart recovery, and duplicate suppression independently.

### Incremental Delivery

1. Add complete review/check context and failure suppression through User Story 2.
2. Add evidence-backed human handoff and later-event semantics through User Story 3.
3. Align contracts and run the full quality gate in Phase 6.

## Notes

- `[P]` means different files or independently authorable fixture groups with no incomplete dependency.
- `[US#]` maps each task to its specification user story.
- Custom checklist markers are reviewer-owned and are not modified during implementation.
- Commit after coherent task groups and stop on a failing sequential dependency.
