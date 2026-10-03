# Tasks: Link Pull Requests to Source Issues

**Input**: Design documents from `specs/gh-10-link-pr-issue/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/pr-tracking-reference.md`, `quickstart.md`

**Tests**: Focused regression tests are required by SC-005, the approved plan, and Constitution V. Write and observe the focused test failure before changing workflow policy.

**Organization**: Tasks are grouped by user story so the reviewer-facing link and issue-facing reciprocal discovery can be implemented and evaluated as distinct increments.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes a different file and has no dependency on an incomplete task
- **[Story]**: Maps the task to a user story in `spec.md`
- Every task names the exact file it changes or validates

## Phase 1: User Story 1 - See the source issue from the pull request (Priority: P1) 🎯 MVP

**Goal**: Require one same-repository, non-closing tracking reference in every created or updated Symphony PR body while preserving explicit issue-closure ownership.

**Independent Test**: Render or inspect the reusable GitHub Spec Kit workflow and confirm it requires exactly one `Tracks #{{ issue.id }}` line, forbids auto-closing keywords, preserves the repository PR template, and leaves issue closure to merged-PR handling.

### Tests for User Story 1

- [X] T001 [US1] Add a focused failing workflow-contract test for the exact `Tracks #{{ issue.id }}` requirement, forbidden closing keywords, PR-template preservation, and separate merged-PR issue closure in `elixir/test/symphony_elixir/github_launcher_test.exs`

### Implementation for User Story 1

- [X] T002 [US1] Update PR create/update instructions to require exactly one same-repository `Tracks #{{ issue.id }}` line, prohibit auto-closing keywords, retain body validation, and preserve explicit merged-PR closure handling in `elixir/examples/github-speckit-WORKFLOW.md`
- [X] T003 [P] [US1] Document the non-closing tracking reference, the forbidden closing relationship, and separate issue-closure responsibility in `elixir/docs/github-workflow-control.md`
- [X] T004 [US1] Run the focused test from `specs/gh-10-link-pr-issue/quickstart.md` and confirm `elixir/test/symphony_elixir/github_launcher_test.exs` passes after T002

**Checkpoint**: The reusable workflow makes the source issue directly reachable from the PR without assigning closure semantics to the relationship.

---

## Phase 2: User Story 2 - See the pull request from the issue (Priority: P2)

**Goal**: Make the same PR-body reference create one reciprocal GitHub cross-reference on the issue across revisions and recovery paths.

**Independent Test**: Validate a representative template-compliant PR body with one `Tracks #10` line, confirm the canonical line occurs exactly once and contains no closing keyword, and review the documented create/update/retry invariant.

### Tests and Integration for User Story 2

- [X] T005 [US2] Extend the workflow-contract assertions for create, update, retry, revision, and close-without-merge paths so they preserve one canonical reference and keep the issue open in `elixir/test/symphony_elixir/github_launcher_test.exs`
- [X] T006 [US2] Validate a representative body copied from `.github/pull_request_template.md` with exactly one `Tracks #10` line using `elixir/lib/mix/tasks/pr_body.check.ex`, and record the result for implementation handoff
- [X] T007 [US2] Run the disposable-repository create, revision, close-without-merge, and merge checks from `specs/gh-10-link-pr-issue/quickstart.md` to observe reciprocal GitHub presentation and non-closing semantics, or record the unavailable credential/repository prerequisite as a PR validation omission

**Checkpoint**: The issue-facing relationship is specified as one native reciprocal cross-reference and repeated workflow activity cannot duplicate it.

---

## Phase 3: Polish & Cross-Cutting Validation

**Purpose**: Validate all lifecycle paths, governance constraints, and repository-wide quality gates.

- [X] T008 Update `SPEC.md` to document the externally visible non-closing PR-to-issue tracking contract and separate issue-closure ownership while preserving the existing tracker-write boundary
- [X] T009 Perform an adversarial review of create, update, resume, retry, revision, merge, close-without-merge, cancellation, reconciliation, and partial-failure behavior against `.specify/memory/constitution.md`; record any reproducible failure as an incomplete corrective task in `specs/gh-10-link-pr-issue/tasks.md`
- [X] T010 Run `make -C elixir all`, review the diff for secrets, unrelated changes, generated artifacts, incomplete task markers, constitution violations, and required documentation updates, then record validation and dependency-advisory output for the PR body

---

## Dependencies & Execution Order

### Phase Dependencies

- **User Story 1 (Phase 1)**: Starts immediately; T001 must fail before T002, T003 may proceed in parallel with T002 after T001, and T004 follows T002
- **User Story 2 (Phase 2)**: Depends on T002 because it validates the canonical relationship contract; T005 precedes T006 and T007
- **Polish (Phase 3)**: Depends on both user stories; T008 precedes T009 and T010

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on User Story 2 and is the MVP
- **User Story 2 (P2)**: Uses the single PR-body reference established by User Story 1 to produce reciprocal discoverability; it adds lifecycle/idempotency validation rather than a second relationship mechanism

### Parallel Opportunities

- T003 can run in parallel with T002 after the failing test in T001 is observed because it changes documentation rather than the workflow template
- T008 can proceed in parallel with T006 and T007 because it updates the product contract rather than the focused implementation files

## Parallel Example: User Story 1

```text
After T001 demonstrates the missing contract:
Task T002: Update elixir/examples/github-speckit-WORKFLOW.md
Task T003: Update elixir/docs/github-workflow-control.md
```

## Implementation Strategy

### MVP First

1. Complete T001 and observe the focused failure.
2. Complete T002 and T003.
3. Complete T004 to validate User Story 1 independently.
4. Stop for review if only direct PR-to-issue navigation is needed.

### Incremental Delivery

1. Complete User Story 1 to establish the canonical non-closing relationship.
2. Complete User Story 2 to cover reciprocal discovery, idempotency, retry, and close-without-merge behavior.
3. Complete the product-contract update, adversarial lifecycle review, and full quality gate.

## Notes

- Custom checklist markers remain reviewer-owned; implementation does not mark `checklists/lifecycle-traceability.md`
- Mark each task `[X]` only after its described work and validation are complete
- Preserve the repository PR template and never use an auto-closing issue keyword
- Keep workflow policy as the single owner; do not add runtime state or a second relationship operation
