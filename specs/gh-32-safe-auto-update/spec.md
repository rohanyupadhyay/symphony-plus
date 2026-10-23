# Feature Specification: Safe Automatic Updates

**Feature Branch**: `symphony-plus/gh-32-safe-auto-update`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "Symphony Plus should periodically check for changes in the remote main branch on GitHub and auto update, pull, and restart itself without disrupting existing work, when the time is right."

## Clarifications

### Session 2026-10-22

- Q: Which installation type should the first automatic-update release support? → A: Source checkout only.

### Session 2026-10-23

- Q: After a newer revision becomes pending, how should Symphony Plus ensure a continuously busy service eventually reaches a safe update window? → A: Drain new dispatch while already admitted work and its automatic continuations finish.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adopt an Available Update Safely (Priority: P1)

As an operator, I want a continuously running Symphony Plus instance to detect a newer revision on its configured GitHub default branch and adopt it automatically once the service is safe to restart, so that the installation stays current without interrupting agent work.

**Why this priority**: Detecting, deferring, and safely applying the update is the core user value. An update that interrupts work or changes revisions unsafely is worse than no automatic update.

**Independent Test**: Run the service from an eligible installation at an older revision, publish a newer default-branch revision, keep one unit of managed work active through at least one update check, then let the runtime become quiescent. The service must defer while work is active and subsequently restart on the newer revision without losing recoverable workflow state.

**Acceptance Scenarios**:

1. **Given** an eligible installation whose configured remote default branch has advanced, **When** the periodic check runs while managed work is active or waiting for an automatic continuation, **Then** the service records the pending update, stops admitting unrelated new issue work, and allows already admitted work and its automatic continuations to finish without interruption.
2. **Given** a pending update and a quiescent runtime, **When** the safe restart conditions remain true through update admission, **Then** the service adopts exactly the detected revision and restarts using the same workflow and operator configuration.
3. **Given** a restarted service after an update, **When** startup reconciliation runs, **Then** durable issue workspaces, workflow checkpoints, quota-wait records, and merge-queue records remain available and are reconciled under the existing lifecycle rules.

---

### User Story 2 - Refuse Unsafe Updates (Priority: P2)

As an operator, I want automatic updating to stop safely when the installation cannot be advanced without overwriting local state or violating repository history, so that automation never destroys operator changes or installs an unexpected revision.

**Why this priority**: Automatic mutation of the running installation needs strict boundaries and actionable failure behavior.

**Independent Test**: Exercise dirty, detached, divergent, unreachable, and failed-update conditions and show that the running revision and local changes are preserved, no restart is attempted, and the operator receives a concise reason and recovery action.

**Acceptance Scenarios**:

1. **Given** local tracked or untracked changes overlap the installation update, **When** an update is due, **Then** no installation files are overwritten and the operator is told why the update was blocked.
2. **Given** the local revision cannot advance to the detected remote revision by the supported history rule, **When** the updater evaluates it, **Then** it refuses the update without resetting, rebasing, or deleting local history.
3. **Given** fetching, preparing, validating, or activating an update fails, **When** the failure is observed, **Then** the current service remains usable or is recoverably restarted on the prior working revision, and the failure is reported without exposing credentials.

---

### User Story 3 - Operate and Observe Update Policy (Priority: P3)

As an operator, I want update behavior to be explicitly configurable and observable, so that I can disable it, choose a suitable check cadence, understand pending or blocked updates, and confirm the running revision.

**Why this priority**: Automatic self-mutation must be opt-in and transparent, but the safety mechanism can be delivered before richer status presentation.

**Independent Test**: Start separate instances with updating disabled and enabled, vary the configured cadence, and inspect operator-visible status and logs for no-update, pending, applied, and blocked outcomes.

**Acceptance Scenarios**:

1. **Given** automatic updating is disabled, **When** the service runs beyond the normal check interval, **Then** it does not contact the update source or mutate its installation.
2. **Given** automatic updating is enabled with valid configuration, **When** checks find no newer revision, **Then** the service continues normally without restart and avoids noisy repeated reporting.
3. **Given** an update is pending or blocked, **When** the operator inspects service status, **Then** the current revision, candidate revision, last-check outcome, and the reason for deferral or blockage are available without secrets.

### Edge Cases

- The remote becomes unavailable, rate-limited, or returns an authentication error during a check.
- The remote default branch changes between detection, admission, and activation.
- Unrelated new work becomes runnable after an update is detected while already admitted work is still draining.
- A retry timer, quota renewal, workflow checkpoint, or queued merge exists while no agent process is currently executing.
- Multiple update checks overlap or repeatedly observe the same candidate revision.
- The candidate revision fails preparation or validation before activation.
- The process exits for activation but its external restart mechanism is unavailable or fails.
- More than one Symphony Plus process points at the same installation directory.
- The configured remote or branch no longer exists, or the local checkout is detached or divergent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Automatic updating MUST be disabled by default and MUST require explicit operator configuration before the service contacts an update source or mutates its installation.
- **FR-002**: When enabled, the service MUST check its configured GitHub repository default branch at a configurable positive interval and MUST prevent overlapping checks.
- **FR-003**: The service MUST compare immutable revision identities and MUST treat an already observed or running revision as current without repeatedly attempting it.
- **FR-004**: The service MUST record a newer eligible revision as pending without interrupting active agent sessions, retries eligible for automatic continuation, quota waits, workflow resumptions, automatic review, or merge-queue activity, and MUST allow that already admitted work and its automatic continuations to finish.
- **FR-005**: Once an eligible revision is pending, one authoritative lifecycle owner MUST stop admitting unrelated new issue work until the update activates successfully or is abandoned safely, so continuous arrivals cannot indefinitely postpone the update.
- **FR-006**: The service MUST admit restart only when that lifecycle owner determines that all already admitted managed work and its scheduled automatic continuations have drained, and MUST re-check that condition immediately before activation.
- **FR-007**: The service MUST preserve and reconcile all existing durable work state across an update restart, including issue workspaces, workflow checkpoints, quota-wait records, and merge-queue records.
- **FR-008**: The updater MUST validate that it is operating on the configured installation and remote, MUST refuse dirty, detached, or unsupported divergent states, and MUST NOT reset, rebase, delete, or overwrite local operator work.
- **FR-009**: The updater MUST activate exactly the immutable candidate revision that passed its admission and preparation checks; movement of the remote branch after detection MUST require a new candidate evaluation.
- **FR-010**: Update preparation and activation MUST be serialized so that multiple checks or service processes cannot concurrently mutate the same installation.
- **FR-011**: A failed check MUST leave the running service available and retry on a later interval with bounded reporting; it MUST NOT stop managed work solely because the update source is unavailable.
- **FR-012**: A failed preparation or activation MUST preserve or restore a runnable prior installation and MUST expose an actionable blocked outcome instead of entering an unbounded restart loop.
- **FR-013**: The service MUST expose the running revision, last update check time and outcome, pending candidate revision, and any deferral or blocked reason through existing operator-visible status and structured logging.
- **FR-014**: Update lifecycle logs MUST use stable, concise wording, include the installation and revision context needed for diagnosis, and MUST NOT contain repository credentials, tokens, private keys, or unnecessary remote payloads.
- **FR-015**: Configuration changes that disable automatic updating MUST take effect without waiting for the next restart; changes to update-source or activation settings MUST be validated before replacing the last known-good settings.
- **FR-016**: The first release MUST support only a clean source checkout that can fast-forward to the admitted revision, rebuild, and restart through the documented launcher or supervisor boundary; downloaded release executables and mixed installation modes are out of scope.
- **FR-017**: The operator documentation MUST define eligibility, safe-idle semantics, update/restart ownership, failure recovery, configuration, and the external mechanism responsible for bringing the process back after activation.

### Key Entities

- **Update Policy**: Operator-owned settings that enable checks and define their cadence and supported update source.
- **Running Revision**: The immutable revision identity currently executing and the installation it belongs to.
- **Update Candidate**: A detected immutable revision, its source branch, detection time, preparation state, and latest outcome.
- **Update Admission**: The decision that dispatch is paused and the runtime is sufficiently quiescent to activate one candidate.
- **Update Status**: Operator-visible current, pending, deferred, blocked, or failed state plus concise diagnostic context.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In lifecycle tests, 100% of update checks performed while managed work is running or scheduled for automatic continuation leave that work uninterrupted and defer restart.
- **SC-002**: After the runtime becomes safely quiescent, an eligible pending revision is activated and the service is available on that exact revision within two configured check intervals plus the documented preparation and restart allowance.
- **SC-003**: Across restart-recovery scenarios, 100% of durable issue workspaces, checkpoints, quota waits, and merge-queue records present before activation remain reconcilable after startup.
- **SC-004**: Across dirty, detached, divergent, concurrent-updater, preparation-failure, and activation-failure scenarios, no operator file or repository history is lost or silently rewritten.
- **SC-005**: Operators can identify the running revision and distinguish current, pending, deferred, blocked, and failed update outcomes from the existing status surface and logs within one minute.
- **SC-006**: When automatic updating is disabled, a 24-hour observation produces zero update-source requests and zero installation mutations attributable to the updater.

## Assumptions

- The first version follows only the configured repository's GitHub default branch; arbitrary channels, tags, downgrades, and rollback selection are out of scope.
- “The time is right” means the runtime has no active or automatically resumable managed work, not merely that no child agent process exists at one instant.
- The updater never mutates issue workspaces; it mutates only the validated Symphony Plus installation target.
- Update checks use existing host-side authentication boundaries and never provide repository credentials to coding-agent child processes.
- An external launcher or service supervisor remains responsible for guaranteeing that a deliberately stopped process starts again; the service must coordinate with and document that boundary.
- Multi-node coordinated rollout is out of scope. A filesystem-level ownership mechanism prevents concurrent mutation of one installation by multiple local processes.
- Published executable replacement and mixed source/executable installation modes are out of scope for the first release.
