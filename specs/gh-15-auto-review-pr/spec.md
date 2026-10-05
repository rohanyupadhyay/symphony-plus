# Feature Specification: Automatically Review Symphony Pull Requests

**Feature Branch**: `symphony/gh-15-auto-review-pr`

**Created**: 2026-10-03

**Status**: Draft

**Input**: User description: "When Symphony Plus creates a pull request for an issue labeled `symphony`, label the pull request `symphony` too and automatically review, test, and repair it until it is ready for human review."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatically begin pull request review (Priority: P1)

As a maintainer, I want a pull request created by Symphony for a `symphony` issue to enter an automated review pass without another command so defects are found before human review.

**Why this priority**: Automatic continuation from implementation into review is the feature's primary value and removes an otherwise manual handoff.

**Independent Test**: Let Symphony create a pull request from an eligible issue and observe that the pull request receives the `symphony` label and an automated review starts without a human comment or approval.

**Acceptance Scenarios**:

1. **Given** an issue that carries the `symphony` label, **When** Symphony creates its pull request, **Then** the pull request also carries the `symphony` label.
2. **Given** that newly created and labeled pull request, **When** the next scheduling opportunity occurs, **Then** Symphony begins reviewing it without waiting for an additional human trigger.
3. **Given** repeated polling or a service restart after the pull request is created, **When** eligibility is reconstructed, **Then** no duplicate concurrent review is started for the same pull request and branch.

---

### User Story 2 - Repair review and validation failures (Priority: P1)

As a maintainer, I want Symphony to address actionable review findings and failing checks so the pull request reaches human review with known defects resolved.

**Why this priority**: Starting a review without acting on its findings would not reduce reviewer effort or improve pull request readiness.

**Independent Test**: Create an eligible Symphony pull request containing a reproducible defect and a failing required check; the automated pass reports the findings, makes scoped corrections, runs appropriate tests, and updates the same pull request.

**Acceptance Scenarios**:

1. **Given** an eligible pull request with code or documentation defects, **When** Symphony reviews it, **Then** Symphony records actionable findings and corrects findings that can be safely resolved within the pull request's approved scope.
2. **Given** an eligible pull request with failed or errored GitHub checks, **When** Symphony reviews it, **Then** Symphony investigates each failure, fixes failures caused by the pull request, and reruns or awaits the relevant validation evidence.
3. **Given** a pull request whose change needs additional targeted testing, **When** Symphony reviews the risk and affected behavior, **Then** it adds or runs the tests needed to demonstrate the corrected behavior.
4. **Given** an external, flaky, permission-related, or otherwise non-code failure, **When** Symphony cannot safely correct it, **Then** it reports the exact blocker and preserves the pull request for human action rather than making unrelated changes.

---

### User Story 3 - Hand off a review-ready pull request (Priority: P2)

As a human reviewer, I want a concise, evidence-backed handoff so I can focus on judgment rather than rediscovering automated review results.

**Why this priority**: Human approval remains mandatory, and the automated pass must leave a trustworthy audit trail.

**Independent Test**: Complete an automatic review pass and inspect the pull request and originating issue; they identify the same pull request, show validation evidence and unresolved limitations, and wait for human review without merging.

**Acceptance Scenarios**:

1. **Given** all actionable findings are resolved and relevant checks pass, **When** the automated pass completes, **Then** Symphony posts a concise summary of review scope, changes, tests, check results, and omissions.
2. **Given** the automated pass completes, **When** the pull request is handed off, **Then** human review and approval are still required and Symphony does not merge solely because its own review passed.
3. **Given** later formal requested changes or new failing checks, **When** the durable review workflow resumes, **Then** Symphony handles only new actionable events and updates the same branch and pull request.

### Edge Cases

- The `symphony` label already exists on the pull request when creation handling is retried.
- The label operation succeeds but review dispatch is interrupted, or review dispatch occurs after a restart.
- The pull request is created from an issue that no longer carries the required label by the time creation completes.
- Multiple labeled pull requests refer to one originating issue or branch; the workflow must not create competing writers.
- The pull request is from a fork, targets another repository, is created by a human, or merely mentions a labeled issue without having been created by Symphony.
- GitHub checks are pending, skipped, cancelled, stale, flaky, or unavailable because of permissions or an external service.
- Review finds scope expansion, a security-sensitive change, or an architectural decision that requires human authorization rather than an automatic fix.
- The pull request is closed or merged while an automated review is queued or running.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A pull request created by Symphony from or for an issue carrying the `symphony` label MUST receive the `symphony` label as part of the creation workflow.
- **FR-002**: Label application MUST be idempotent and MUST NOT create duplicate labels or duplicate review work when creation handling is retried.
- **FR-003**: The newly created eligible pull request MUST enter an automated review pass without requiring a new human comment, approval, or manual relabeling action.
- **FR-004**: The system MUST preserve exactly one authoritative workflow owner for a pull request and its branch so the originating issue flow and pull request flow cannot mutate the branch concurrently.
- **FR-005**: Automatic review eligibility MUST be recoverable from GitHub-visible state after service restart without relying on an in-memory-only handoff.
- **FR-006**: The automated pass MUST inspect the complete pull request diff, existing conversation, formal reviews, inline comments, and current GitHub check results before deciding what work remains.
- **FR-007**: The automated pass MUST assess correctness, security and credential safety, lifecycle and recovery behavior, test adequacy, documentation, scope discipline, and compliance with repository contracts that apply to the changed area.
- **FR-008**: For every actionable finding within the authorized scope, Symphony MUST either correct it on the existing pull request branch or record a specific justified reason that it cannot be corrected automatically.
- **FR-009**: Symphony MUST investigate failed or errored checks, distinguish pull-request-caused failures from external or flaky failures, and MUST NOT make unrelated changes merely to force a check to pass.
- **FR-010**: Symphony MUST run targeted validation appropriate to each correction and the repository's required full quality gate before declaring the pull request review-ready, unless a recorded blocker makes a check impossible.
- **FR-011**: Corrections MUST update the same pull request and branch; the automated review MUST NOT open a second pull request for the same review cycle.
- **FR-012**: Repeated polls, retries, restarts, and review resumptions MUST process only unhandled review or check events and MUST NOT start duplicate concurrent work.
- **FR-013**: Removing the required label, closing or merging the pull request, or closing the originating issue MUST prevent new automatic work and stop or safely reconcile in-progress work according to the durable workflow state.
- **FR-014**: On completion or blockage, Symphony MUST provide an operator-visible summary of findings, corrections, targeted and full validation, check status, omissions, and any action required from a human.
- **FR-015**: Automatic review completion MUST hand the pull request to a human reviewer and MUST NOT bypass required human approval or repository merge policy.
- **FR-016**: Pull requests not created by Symphony for an eligible labeled issue MUST NOT be automatically enrolled merely because they mention, link to, or share a branch name with such an issue.
- **FR-017**: The product contract and GitHub operator documentation MUST describe pull request label inheritance, automatic review eligibility, durable recovery, single-owner behavior, and human-review handoff.

### Key Entities

- **Originating Issue**: The labeled GitHub issue that authorized Symphony to create and advance the change.
- **Managed Pull Request**: The single pull request created by Symphony for the originating issue, carrying durable repository, number, branch, label, check, and review context.
- **Review Cycle**: One idempotent automatic assessment and repair pass over a managed pull request, including the GitHub event cursor needed to avoid duplicate handling.
- **Review Finding**: An actionable or informational observation with severity, evidence, disposition, and validation status.
- **Check Result**: A pending or completed GitHub validation result classified as passing, pull-request-caused failure, external/flaky failure, or blocked/unavailable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of pull requests created by Symphony for issues labeled `symphony`, the pull request carries the `symphony` label before the creation workflow hands off.
- **SC-002**: In 100% of eligible creation scenarios, an automated review begins by the next successful scheduling opportunity without a human trigger.
- **SC-003**: Repeated polls, retries, and restart recovery produce zero concurrent duplicate review runs for the same pull request and branch.
- **SC-004**: Every completed automatic review accounts for 100% of current formal reviews, inline comments, pull request conversation entries, and completed required checks as handled, non-actionable, or explicitly blocked.
- **SC-005**: Every automatically corrected finding has recorded targeted validation, and every review-ready handoff has a passing full repository quality gate.
- **SC-006**: Automatic review causes zero merges without the repository's required human approval and status checks.
- **SC-007**: Lifecycle validation covers creation, repeated polling, restart recovery, label removal, new review feedback, failing checks, close-without-merge, and merge-during-review scenarios.

## Assumptions

- A pull request is considered Symphony-created only when the durable issue workflow records it as the pull request for that originating issue; author identity or textual references alone are insufficient.
- Automatic review is a continuation of the originating issue's authorized scope, regardless of whether scheduling represents it as the issue or pull request internally.
- Exactly one active worker owns mutations to the pull request branch at a time.
- Existing durable approval and review checkpoints remain the source of recovery and human control.
- The repository's normal review guidance and required checks define the baseline review method; provider-specific review assistance may supplement but does not replace repository validation.
- Fork-based or cross-repository pull requests are outside the initial scope.
