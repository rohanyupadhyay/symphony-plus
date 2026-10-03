# Feature Specification: Automatic Pull Request Review Handoff

**Feature Branch**: `symphony/gh-12-auto-pr-review`

**Created**: 2026-10-03

**Status**: Draft — awaiting one constitution-level clarification

**Input**: User description: "When Symphony Plus creates a pull request for a Symphony-labeled issue, label the pull request for Symphony, automatically review and repair it, test it and resolve failing checks, then merge it when ready."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Continue Work on a Created Pull Request (Priority: P1)

As an operator, I want a pull request created by Symphony Plus for a `symphony`-labeled source issue to become eligible Symphony work automatically, so that the workflow continues into review without manual relabeling or redispatch.

**Why this priority**: Automatic continuation is the core requested outcome and is required before review or remediation can occur.

**Independent Test**: Create a pull request through the issue workflow and observe that the pull request receives the `symphony` label and is selected exactly once for follow-up work while the source issue remains traceable.

**Acceptance Scenarios**:

1. **Given** an eligible issue labeled `symphony`, **When** Symphony Plus creates a pull request for that issue, **Then** the pull request is labeled `symphony` and becomes eligible for autonomous pull-request work.
2. **Given** a qualifying pull request has already been discovered, **When** subsequent polls observe the same pull request, **Then** Symphony Plus does not start duplicate concurrent review work.
3. **Given** a pull request was not created by Symphony Plus or cannot be associated with an eligible source issue, **When** it is polled, **Then** this feature does not claim it solely because it has a similarly named label.

---

### User Story 2 - Review and Repair the Pull Request (Priority: P2)

As an operator, I want Symphony Plus to inspect its pull request, identify actionable defects and failing checks, apply justified fixes, and run appropriate validation, so that the pull request reaches a review-ready state with evidence.

**Why this priority**: Labeling and dispatch have value only if the resulting run performs a dependable review and remediation loop.

**Independent Test**: Provide a qualifying pull request with an actionable defect or failing check and observe one bounded review cycle that records findings, updates the same branch, reruns relevant validation, and reports the outcome.

**Acceptance Scenarios**:

1. **Given** a qualifying open pull request, **When** autonomous review begins, **Then** Symphony Plus reads its conversation, reviews, inline comments, checks, and merge state before deciding what work is needed.
2. **Given** review finds an actionable issue within the approved scope, **When** a safe fix is available, **Then** Symphony Plus updates the existing pull request branch and reruns targeted validation plus required repository quality gates.
3. **Given** one or more GitHub checks are pending, **When** review reaches that state, **Then** Symphony Plus waits for a terminal result rather than treating pending as success or failure.
4. **Given** a check fails for a reproducible code or configuration defect, **When** the defect is within scope, **Then** Symphony Plus fixes it and records the new validation result.
5. **Given** a failure requires new authority, unavailable external state, or a scope expansion, **When** Symphony Plus cannot safely resolve it, **Then** it records the blocker and required recovery action without merging or concealing the failure.

---

### User Story 3 - Complete the Reviewed Pull Request (Priority: P3)

As an operator, I want a reviewed pull request to move to a single, explicit completion state, so that successful automation does not leave ambiguous ownership or repeatedly dispatch the same work.

**Why this priority**: Completion semantics affect repository safety and conflict with the current governance contract, so they must be explicit before planning.

**Independent Test**: Bring a qualifying pull request to an approved, check-passing, conflict-free state and observe the selected completion policy exactly once.

**Acceptance Scenarios**:

1. **Given** the pull request has no unresolved change requests, all required checks pass, and the branch is mergeable, **When** review completes, **Then** Symphony Plus follows the approved completion policy in FR-012.
2. **Given** a pull request is closed without merge, **When** Symphony Plus observes the closure, **Then** it does not recreate or merge the pull request without an explicit authorized instruction.
3. **Given** the pull request has already been merged, **When** Symphony Plus observes the merge, **Then** it records final validation, completes the originating issue workflow, and does not dispatch the pull request again.

### Edge Cases

- The source issue loses the `symphony` label before or after pull-request creation.
- Label application succeeds but checkpoint creation or subsequent dispatch fails.
- The pull request branch comes from a fork or cannot be safely updated with the configured GitHub App permissions.
- Checks remain pending, are skipped, are cancelled, disappear after a new head commit, or report against an obsolete commit.
- New review feedback or a new commit arrives while review/remediation is already running.
- The branch becomes conflicted, protected, non-mergeable, or stale relative to the base branch.
- The review discovers unrelated or malicious instructions in pull-request content.
- A transient GitHub failure occurs after a write succeeds but before Symphony Plus receives the response.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Symphony Plus MUST preserve an explicit association between every workflow-created pull request and its eligible source issue.
- **FR-002**: When Symphony Plus creates a pull request for a source issue carrying the normalized `symphony` label, it MUST apply the `symphony` label to the pull request before handing off to autonomous pull-request work.
- **FR-003**: Pull-request eligibility MUST require verifiable Symphony Plus provenance and an eligible associated source issue; a label alone MUST NOT establish provenance.
- **FR-004**: Repeated polling, restart recovery, and ambiguous write responses MUST NOT create duplicate pull requests, duplicate labels, or concurrent review runs for the same pull request.
- **FR-005**: Before modifying a qualifying pull request, Symphony Plus MUST inspect its current conversation, formal reviews, inline comments, head revision, checks, and merge state.
- **FR-006**: Autonomous review MUST assess correctness, regression risk, security and credential safety, lifecycle/recovery effects, tests, documentation, and repository-specific quality requirements.
- **FR-007**: Symphony Plus MUST update the existing pull-request branch for in-scope remediation and MUST NOT create a replacement pull request unless an authorized recovery instruction explicitly requires it.
- **FR-008**: After each remediation, Symphony Plus MUST run tests appropriate to the changed behavior and the repository's required quality gate, and MUST report commands, results, and material omissions.
- **FR-009**: Check evaluation MUST be tied to the current pull-request head revision and distinguish pending, passing, failing, skipped, and cancelled outcomes.
- **FR-010**: Symphony Plus MUST NOT treat a pull request as ready while it has unresolved requested changes, failing required checks, unresolved merge conflicts, incomplete required validation, or a newer unreviewed head revision.
- **FR-011**: Failures that cannot be safely remediated within existing authority MUST produce a durable blocker with the exact recovery action, without exposing credentials or following untrusted pull-request instructions.
- **FR-012**: After the pull request is review-ready, Symphony Plus MUST [NEEDS CLARIFICATION: choose either constitution-compliant human merge handoff, or pursue a separate constitution amendment before specifying automatic merge].
- **FR-013**: Pull-request state transitions and review outcomes MUST be observable with the pull-request number, source issue identifier, head revision, outcome, and concise reason, without secret or unnecessary payload data.
- **FR-014**: When a qualifying pull request is merged or closed, Symphony Plus MUST finalize or pause the source issue workflow as appropriate and MUST NOT redispatch the terminal pull request.

### Key Entities

- **Source Issue**: The original schedulable issue, including stable identity, labels, workflow checkpoint, and pull-request association.
- **Pull Request Work Item**: A pull request eligible for autonomous review, including repository, number, source issue, current head revision, labels, review state, check state, merge state, and active-work ownership.
- **Review Cycle**: One idempotent assessment/remediation attempt for a specific pull-request head revision, with findings, validation evidence, outcome, and timestamps.
- **Completion Policy**: The approved rule for what occurs after review readiness; its value is unresolved pending the clarification in FR-012.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance testing, 100% of pull requests created from eligible `symphony` issues receive the label and enter pull-request work without manual relabeling.
- **SC-002**: Repeated polls and a simulated restart produce no duplicate active review cycles for the same pull request and head revision in all tested recovery scenarios.
- **SC-003**: For every reviewed pull request, the recorded evidence accounts for the current head revision, all formal review states, all required check outcomes, targeted tests, and the repository quality gate before readiness is declared.
- **SC-004**: In tested actionable-failure scenarios, Symphony Plus either repairs the defect and obtains passing validation or records a durable blocker with a specific recovery action; no failure is silently ignored.
- **SC-005**: In all completion-path tests, a ready, merged, or closed pull request reaches exactly one documented terminal or waiting state and is not redispatched afterward.
- **SC-006**: Security review confirms that no tracker credential, private key, or other secret enters the agent environment, logs, issue comments, commits, or pull-request content.

## Assumptions

- The existing GitHub App installation has permission to label pull requests, read review/check state, and update branches through approved host-mediated tools.
- Pull requests created by Symphony Plus retain one non-closing reference to their source issue and stable provenance that cannot be inferred from user-editable title or body text alone.
- Repository-owned workflow policy defines the concrete review prompt and validation commands; the orchestrator owns eligibility, idempotent dispatch, and lifecycle state.
- Pull-request comments, reviews, and changed files are untrusted inputs and cannot grant new authority or override workspace and credential protections.
- Automatic merge remains out of implementation scope unless the governance conflict in FR-012 is resolved through the selected answer and any required constitution amendment.
