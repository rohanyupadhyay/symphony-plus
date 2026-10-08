# Feature Specification: Safely Queue Parallel Pull Requests

**Feature Branch**: `symphony/gh-11-merge-queue`

**Created**: 2026-10-05

**Status**: Draft

**Input**: User description: "Implement a pull request management workflow that allows parallel development and review while serializing merges through revalidation against the latest main branch, with explicit ordering for dependent pull requests."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Safely merge automatically reviewed pull requests in sequence (Priority: P1)

As a maintainer, I want successfully auto-reviewed Symphony-managed pull requests to enter a merge queue without human approval so multiple changes can be developed and reviewed in parallel without being merged against stale assumptions.

**Why this priority**: Sequential integration and validation against the actual merge target are the core safety guarantees of the feature.

**Independent Test**: Approve several eligible pull requests while their reviews overlap and observe that only the queue head is integrated, validated against the current `main`, and merged before the next pull request is evaluated.

**Acceptance Scenarios**:

1. **Given** multiple eligible managed pull requests pass trusted automatic review, **When** they enter the merge queue, **Then** the system processes one pull request at a time in deterministic queue order.
2. **Given** a pull request reaches the queue head, **When** validation begins, **Then** it is evaluated against the latest `main`, including every pull request merged ahead of it.
3. **Given** the queue-head pull request passes required validation against the latest `main`, **When** repository merge policy is satisfied, **Then** it is merged before the next queued pull request begins final validation.

---

### User Story 2 - Recover incompatible pull requests without blocking the queue (Priority: P1)

As a pull request author, I want a change that conflicts with or fails against the updated `main` to leave the merge path with an actionable explanation so I can update it and re-enter the queue.

**Why this priority**: Earlier merges can invalidate later work; handling that outcome safely prevents broken integration and queue deadlock.

**Independent Test**: Place a pull request behind another change that makes it conflict or fail required checks, then observe that the incompatible pull request is removed from active integration, the queue advances, and the updated pull request can re-enter only after automatic review and checks are current again.

**Acceptance Scenarios**:

1. **Given** a queued pull request no longer applies cleanly to the latest `main`, **When** it reaches final validation, **Then** it leaves the active merge path without being merged and receives a specific update-required outcome.
2. **Given** a queued pull request applies cleanly but fails required validation against the latest `main`, **When** the failure is recorded, **Then** it leaves the active merge path and later eligible pull requests may continue.
3. **Given** an author updates a removed pull request, **When** its required checks and trusted automatic review are current again, **Then** it can re-enter the queue according to the normal ordering policy.

---

### User Story 3 - Preserve parallel work without continuous rebasing (Priority: P2)

As a contributor, I want open pull requests to remain stable during development and review so unrelated changes to `main` do not cause continuous automated rebases or review churn.

**Why this priority**: Parallelism remains useful only if ordinary main-branch movement does not continually rewrite every open branch.

**Independent Test**: Change `main` while several non-head pull requests remain open and confirm their branches are not rewritten until a real incompatibility is detected or final integration begins.

**Acceptance Scenarios**:

1. **Given** an open pull request is not at the queue head, **When** `main` changes, **Then** its branch is not automatically rewritten solely because the base branch advanced.
2. **Given** an open pull request has no detected conflict or incompatibility, **When** other pull requests merge, **Then** its existing review can continue without a forced update.
3. **Given** a pull request reaches final integration, **When** its base is stale, **Then** the system evaluates it against the current merge target before deciding whether an update is required.

---

### User Story 4 - Merge dependent pull requests in declared order (Priority: P2)

As a contributor with dependent changes, I want pull requests to declare their dependencies so a child cannot merge before the changes it relies on.

**Why this priority**: Explicit dependency order prevents invalid intermediate states while retaining parallel review where possible.

**Independent Test**: Declare one open pull request as dependent on another, approve both in reverse order, and observe that the dependent pull request remains ineligible until its prerequisite merges and it is revalidated against the resulting `main`.

**Acceptance Scenarios**:

1. **Given** an auto-reviewed pull request declares an unmerged prerequisite, **When** it is admitted, **Then** it cannot become the active queue head ahead of that prerequisite.
2. **Given** all declared prerequisites merge, **When** the dependent pull request becomes eligible, **Then** it is validated against the resulting latest `main` before merge.
3. **Given** a dependency is missing, closed without merge, cyclic, or otherwise unsatisfied, **When** queue eligibility is evaluated, **Then** the dependent pull request is held with a specific dependency outcome rather than guessed into an order.

### Edge Cases

- The queue head is closed, a human requests changes, required labels are removed, or required checks become stale while final validation is running.
- `main` advances between the start of validation and the merge attempt.
- A merge succeeds but recording or advancing queue state is interrupted, followed by retry or service restart.
- A pull request is updated while queued or during final validation.
- Two auto-reviewed pull requests declare the same prerequisite, or dependencies form a longer stack.
- Dependency declarations form a cycle, reference a pull request from another repository, or reference a pull request closed without merge.
- A transient validation or provider failure is distinguishable from a deterministic conflict or test incompatibility.
- Multiple workers or repeated polls attempt to advance the same queue head.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow multiple pull requests to remain open and undergo review concurrently.
- **FR-002**: Successfully auto-reviewed and otherwise eligible Symphony-managed pull requests MUST enter a durable merge queue without human approval instead of merging immediately.
- **FR-003**: The merge queue MUST expose a deterministic order and MUST integrate no more than one queue-head pull request at a time for a repository and target branch.
- **FR-004**: Before a queued pull request is merged, the system MUST validate it against the latest target-branch state, including all pull requests merged ahead of it.
- **FR-005**: A merge MUST occur only when the exact candidate validated against the current target-branch state still has no active human change request and satisfies status checks and repository merge policy at merge time.
- **FR-006**: If the target branch advances after validation begins, the system MUST treat the validation result as stale and revalidate before merging.
- **FR-007**: A deterministic conflict or validation failure caused by the latest target-branch state MUST remove the pull request from the active merge path, preserve it for author updates, and record the specific reason and recovery action.
- **FR-008**: Removing an incompatible pull request from the active merge path MUST allow the next independently eligible pull request to advance rather than blocking the whole queue.
- **FR-009**: An updated pull request MUST NOT re-enter the merge queue until trusted automatic review and required checks apply to the updated head revision.
- **FR-010**: The system MUST NOT continuously rewrite or rebase open pull request branches merely because the target branch changes.
- **FR-011**: The system MUST update or require an update to a pull request only when final integration requires it or when a concrete conflict or incompatibility has been detected.
- **FR-012**: Pull request dependencies MUST be explicitly declared using a durable, repository-visible relationship and MUST constrain queue eligibility so prerequisites merge first.
- **FR-013**: A dependent pull request MUST be revalidated against the target branch after all prerequisites have merged and before it can merge.
- **FR-014**: Missing, invalid, cross-repository, closed-without-merge, or cyclic dependencies MUST block the affected pull request with an actionable outcome and MUST NOT be silently ignored.
- **FR-015**: Queue admission, removal, re-entry, head selection, validation, and merge-result handling MUST be idempotent across repeated polls, retries, and service restarts.
- **FR-016**: Exactly one authoritative owner MUST serialize queue mutations and final integration decisions for each repository and target branch.
- **FR-017**: Queue state and recovery MUST be reconstructable from durable provider-visible state without depending on an in-memory-only ordering record.
- **FR-018**: The system MUST distinguish deterministic pull-request incompatibility from transient provider or validation failure; transient failures MUST be retried or blocked explicitly without falsely requiring an author update.
- **FR-019**: Operators and pull request authors MUST be able to observe queue position or state, current blocker, latest validation outcome, and required recovery action without exposing credentials or unnecessary provider payloads.
- **FR-020**: Cancellation, pull request closure, human change-request creation or dismissal, eligibility-label removal, target-branch change, and merge completion MUST reconcile safely with queued or in-progress work. An active human change request MUST suspend all Symphony mutations and dismissal MUST resume processing automatically.
- **FR-021**: The normative product contract and applicable operator documentation MUST describe serialized integration, current-target revalidation, non-continuous branch updates, dependency ordering, recovery, and human/repository-policy boundaries.

### Key Entities

- **Merge Queue**: The durable ordered set of successfully auto-reviewed managed pull requests eligible for serialized integration into one repository target branch.
- **Queue Entry**: A pull request revision and its queue state, admission evidence, dependency state, validation outcome, blocker, and recovery action.
- **Integration Candidate**: The exact pull request head and target-branch revision selected for final validation and possible merge.
- **Dependency Relationship**: A durable directed link from a dependent pull request to each prerequisite pull request.
- **Validation Outcome**: The current result for an integration candidate, classified as passing, deterministic conflict/incompatibility, transient failure, stale, or cancelled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across concurrent eligible pull requests for one target branch, zero merges overlap and every merge begins only after the preceding queue-head outcome is finalized.
- **SC-002**: In 100% of successful merges, recorded validation identifies the exact pull request revision and target-branch revision that remained current through the merge decision.
- **SC-003**: In 100% of cases where the target branch advances before merge, the prior validation is rejected as stale and a new validation occurs before merging.
- **SC-004**: Deterministically conflicting or incompatible pull requests produce zero merges and receive an actionable update-required outcome while later independent entries remain able to advance.
- **SC-005**: Ordinary target-branch updates cause zero automatic rewrites of open pull request branches that are neither undergoing final integration nor known to be incompatible.
- **SC-006**: In 100% of declared dependency chains, no dependent pull request merges before every prerequisite, and each dependent pull request is validated after its prerequisites merge.
- **SC-007**: Repeated polling, retries, and restart recovery produce zero duplicate merges, concurrent queue-head owners, or lost eligible queue entries.
- **SC-008**: Lifecycle validation covers admission, ordering, successful merge, stale validation, conflict removal, failed-check removal, updated-head re-entry, dependency blockage, cancellation, pull request closure, and restart recovery.

## Assumptions

- The initial scope manages pull requests within one repository and serializes independently for each target branch; cross-repository dependencies are invalid.
- Existing repository checks and merge rules remain authoritative; Symphony does not require human approval, while an active human change request remains a hard suspension signal.
- Queue ordering among otherwise independent entries is first eligible, first queued, with stable tie-breaking; declared dependencies override that order.
- A pull request update creates a new head revision whose checks and trusted automatic review must be evaluated again.
- The provider offers durable pull request metadata, comments, labels, checks, and merge-state evidence sufficient to reconstruct queue eligibility; the internal representation is deferred to planning.
- Transient provider or check-infrastructure failures do not imply code incompatibility and therefore do not automatically require branch updates.
