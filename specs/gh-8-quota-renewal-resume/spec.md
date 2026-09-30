# Feature Specification: Quota-Aware Harness Resume

**Feature Branch**: `symphony/gh-8-quota-renewal-resume`

**Created**: 2026-09-30

**Status**: Draft — clarification required

**Input**: User description: "Once quota exhausts and renews, tasks such as GitHub issue workflows should automatically pause or save state where necessary and continue using the previous context without starting fresh. This should account for harnesses such as Codex, Claude, and GitHub Copilot."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pause Work at Quota Exhaustion (Priority: P1)

As an operator, I want Symphony to recognize a coding harness quota exhaustion as a recoverable waiting condition so that active work is preserved instead of repeatedly failing, consuming retry capacity, or being restarted from the beginning.

**Why this priority**: Correctly entering a safe waiting state is the minimum viable protection against lost work and wasteful retry loops.

**Independent Test**: Simulate a harness reporting quota exhaustion with a known renewal time and confirm that the affected task becomes quota-paused, retains its workspace and continuation identity, consumes no active execution slot, and is not retried before it is eligible.

**Acceptance Scenarios**:

1. **Given** an active task whose harness reports that quota is exhausted with a renewal time, **When** Symphony processes the report, **Then** the task is moved to a quota-paused state until that time and its resumable state is preserved.
2. **Given** a quota-paused task, **When** ordinary polling and reconciliation repeat before renewal, **Then** Symphony does not launch duplicate work or increment failure retry attempts.
3. **Given** several active tasks using the same exhausted quota pool, **When** exhaustion is recognized, **Then** Symphony prevents further dispatch against that pool while leaving unrelated harnesses and quota pools eligible.

---

### User Story 2 - Resume with Prior Context (Priority: P2)

As an operator, I want quota-paused work to resume after renewal with the prior task context so that the agent continues from its last durable point rather than reinterpreting the issue from scratch.

**Why this priority**: The feature delivers its main user value only if preserved work can make forward progress after renewal.

**Independent Test**: Allow a simulated renewal deadline to pass, make quota available, and confirm that Symphony starts exactly one continuation using the preserved workspace and harness conversation identity, without resending the original task as a fresh run.

**Acceptance Scenarios**:

1. **Given** a quota-paused task with a resumable harness conversation, **When** its renewal time arrives and capacity is available, **Then** Symphony resumes that conversation in the same issue workspace with continuation guidance.
2. **Given** a quota-paused task whose first post-renewal attempt still reports exhaustion, **When** Symphony processes that report, **Then** it safely returns the task to quota-paused state using the latest valid renewal information without duplicating execution.
3. **Given** multiple quota-paused tasks become eligible together, **When** quota renews, **Then** normal global and per-state concurrency rules bound their resumption.

---

### User Story 3 - Understand and Recover Quota Waits (Priority: P3)

As an operator, I want quota-wait status and recovery decisions to be visible so that I can distinguish expected waiting from failures and intervene when automatic renewal cannot be determined.

**Why this priority**: Clear status and logs are required to operate a long-running scheduler safely, especially across restarts and partial failures.

**Independent Test**: Inspect status and structured logs during exhaustion, service restart, renewal, resume, cancellation, and terminal cleanup; confirm that each state and decision is visible with issue, harness, quota-pool, and timing context but no credentials or sensitive provider payloads.

**Acceptance Scenarios**:

1. **Given** a quota-paused task, **When** an operator views system status, **Then** the status distinguishes quota waiting from ordinary failure retries and shows the affected harness, renewal timing if known, and preserved continuation availability.
2. **Given** Symphony restarts while a task is quota-paused, **When** startup recovery completes, **Then** the task remains paused or becomes eligible according to the durable renewal state and current tracker eligibility.
3. **Given** a task becomes terminal, canceled, or unroutable while quota-paused, **When** reconciliation observes the change, **Then** Symphony releases its quota wait and performs the same workspace retention or cleanup policy that applies outside quota waiting.

### Edge Cases

- A harness reports exhaustion without a renewal time, or reports a malformed or past renewal time.
- A quota limit is scoped by account, organization, model, product tier, or another provider-defined pool rather than by an individual task.
- The service restarts between exhaustion and renewal, or exactly while a resume attempt is being dispatched.
- Renewal occurs, but the provider remains unavailable, authentication has expired, or the reported quota is still exhausted.
- The preserved harness conversation no longer exists, is corrupt, belongs to a different workspace, or cannot be resumed by the selected harness.
- A task is canceled, loses its required label, changes to a terminal state, or its workspace is removed while waiting.
- Dynamic configuration reload changes concurrency, retry, or quota-wait policy while tasks are paused.
- Multiple quota notifications for the same pool arrive with different renewal times.
- A provider error resembles quota exhaustion but is actually a transient transport, authentication, billing, or permission failure.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Symphony MUST classify a harness-reported quota exhaustion separately from ordinary worker failure, provider transport failure, authentication failure, operator-input blocking, and normal continuation.
- **FR-002**: A recognized quota exhaustion MUST identify the harness and a stable quota-pool scope sufficient to prevent premature dispatch of other work that would consume the same exhausted allowance.
- **FR-003**: Symphony MUST stop active execution for an exhausted quota pool without deleting the affected issue workspace or durable continuation state.
- **FR-004**: A quota-paused task MUST NOT occupy an active-agent concurrency slot and MUST NOT use the ordinary exponential failure-retry counter while it waits.
- **FR-005**: Symphony MUST durably retain, at minimum, the issue identity, harness identity, quota-pool identity, wait status, renewal timing or unknown-renewal status, preserved workspace identity, continuation identity when available, and last safe transition outcome.
- **FR-006**: Durable quota-wait state MUST survive service restart and MUST be reconciled with current tracker eligibility before any resumed dispatch.
- **FR-007**: When a trustworthy renewal time is available, Symphony MUST avoid resuming the affected quota pool before that time and MUST make eligible work dispatchable after that time subject to normal concurrency and routing rules.
- **FR-008**: When no trustworthy renewal time is available, Symphony MUST use a bounded, operator-visible recheck policy and MUST avoid a tight retry loop.
- **FR-009**: Resume dispatch MUST be idempotent across repeated polls, duplicate exhaustion signals, restart recovery, and simultaneous eligibility changes.
- **FR-010**: A resumed task MUST reuse its preserved issue workspace and, when the harness supports it, its prior native conversation identity; continuation guidance MUST identify remaining work rather than present the task as a new issue.
- **FR-011**: If a post-renewal resume still encounters quota exhaustion, Symphony MUST update the durable wait state from the latest valid signal and return to waiting without duplicating work.
- **FR-012**: Quota-paused work MUST continue to obey cancellation, terminal cleanup, required-label, dispatchability, and dynamic concurrency rules.
- **FR-013**: Status and structured logs MUST expose quota-wait entry, reason category, harness, quota-pool scope, renewal availability, recovery decision, and outcome with applicable issue and session identifiers, while excluding credentials and unnecessary provider payloads.
- **FR-014**: Configuration that governs quota rechecks or recovery MUST flow through the existing service configuration contract and apply to future scheduling decisions after dynamic reload.
- **FR-015**: The initial delivery scope MUST be [NEEDS CLARIFICATION: choose whether to implement Codex end-to-end first behind a harness-neutral quota/resume contract, or require end-to-end support for Codex, Claude, and GitHub Copilot in this feature].
- **FR-016**: When a selected harness cannot resume its prior native conversation, Symphony MUST [NEEDS CLARIFICATION: choose whether to block for operator action, or permit a documented degraded continuation reconstructed from the durable workspace and workflow checkpoint].
- **FR-017**: The specification, operator documentation, and implementation documentation MUST define the selected quota signal mapping, scope semantics, renewal/recheck behavior, persistence guarantees, and degraded recovery policy for every harness included in the delivery scope.

### Key Entities

- **Quota Pool**: A provider-defined allowance shared by one or more tasks; identified by harness plus a stable, non-secret scope and associated with current availability and optional renewal timing.
- **Quota Wait**: Durable scheduler state linking an affected issue to a quota pool, renewal or recheck timing, reason category, attempt metadata, and last transition outcome.
- **Continuation Reference**: Non-secret durable identity needed to continue prior harness context, bound to one issue workspace and validated before reuse.
- **Run Attempt**: One execution attempt extended to distinguish new work, normal continuation, ordinary failure retry, quota resume, and degraded continuation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In automated lifecycle scenarios, 100% of recognized quota-exhaustion events move affected tasks into quota waiting without deleting their workspace or counting the event as an ordinary failure retry.
- **SC-002**: Across repeated polls and a service restart before renewal, zero execution attempts are launched for an exhausted quota pool before its trustworthy renewal time.
- **SC-003**: After quota becomes available, every still-eligible paused task becomes dispatchable within one scheduler polling interval plus 5 seconds, subject to configured concurrency limits.
- **SC-004**: Repeated exhaustion and renewal cycles produce at most one active execution attempt per issue and no duplicate resume dispatches.
- **SC-005**: Every supported restart, cancellation, terminal transition, dynamic reload, malformed-signal, and failed-resume scenario has an automated observable-behavior test.
- **SC-006**: Operator status distinguishes quota waiting from ordinary retrying and blocking for 100% of paused tasks and reports whether native context continuation is available.
- **SC-007**: No credential, authentication token, private key, or raw sensitive provider response is persisted in quota state or emitted in logs, issue comments, or status responses.

## Assumptions

- Quota exhaustion is a recoverable resource-availability condition, not evidence that the issue itself is blocked or invalid.
- A provider-reported renewal time is authoritative only after it is parsed and validated; otherwise the bounded unknown-renewal recheck policy applies.
- Quota state is shared at the narrowest stable scope reported by the harness; unrelated harnesses and distinct quota pools continue operating.
- Existing per-issue workspace safety, tracker reconciliation, and terminal cleanup rules remain authoritative.
- Durable state must not contain harness credentials or raw provider responses.
- A task may remain active in its tracker while Symphony internally marks it quota-paused.

## Out of Scope

- Purchasing quota, changing provider billing plans, rotating credentials, or automatically switching to a different account.
- Moving work to a different model or harness unless separately specified and approved.
- Persisting complete prompts, model outputs, or secret-bearing provider payloads as a substitute for a supported continuation identity.
- Replacing tracker-owned workflow checkpoints or issue state with a new general-purpose workflow engine.
