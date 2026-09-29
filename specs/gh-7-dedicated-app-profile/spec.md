# Feature Specification: Dedicated GitHub App Profile Verification

**Feature Branch**: `symphony/gh-7-dedicated-app-profile`

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "Create a minimal Spec Kit specification describing verification of the dedicated Symphony Plus GitHub App profile and stop at the specification approval checkpoint."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Observe Dedicated App Identity (Priority: P1)

As a Symphony Plus operator, I want the disposable smoke issue's specification branch and durable
approval checkpoint to be written by the configured dedicated GitHub App identity so that I can
confirm the installation is being used instead of a personal or shared credential.

**Why this priority**: The smoke test exists specifically to prove that the dedicated App profile
can perform the GitHub writes required at a specification handoff.

**Independent Test**: Inspect the remote issue branch and specification checkpoint without reading
profile files or credentials. The test succeeds when the pushed branch matches the checkpoint SHA,
the checkpoint is attributed to the configured App bot, and the issue is waiting at the
specification approval gate.

**Acceptance Scenarios**:

1. **Given** the smoke issue is running in its isolated workspace with the dedicated App profile,
   **When** the specification artifacts are committed and published, **Then** the single issue
   branch exists remotely at the exact commit recorded by the checkpoint.
2. **Given** the specification commit is available remotely, **When** the workflow creates its
   durable handoff, **Then** the latest checkpoint is authored by the configured App bot and records
   `awaiting_approval`, phase `specify`, and gate `spec`.
3. **Given** the specification checkpoint has been created, **When** the run finishes, **Then** no
   planning, implementation, pull-request, or merge activity has occurred.

### Edge Cases

- If the branch cannot be published through the dedicated App profile, no approval checkpoint is
  claimed and the failure identifies a recovery action without exposing credential material.
- If the remote branch head and proposed checkpoint SHA differ, the checkpoint is not created.
- If the configured GitHub identity is not the dedicated App bot, the smoke verification fails
  rather than accepting another credential as equivalent.
- Repeated polling or process restart while awaiting approval must preserve one recoverable
  checkpoint and must not advance the workflow or duplicate completed specification work.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The smoke workflow MUST create and retain exactly one issue branch and one Spec Kit
  feature directory for this issue.
- **FR-002**: The workflow MUST publish the specification commit using the configured dedicated
  GitHub App profile through the approved host-mediated push boundary.
- **FR-003**: The workflow MUST record the exact remote branch name and 40-character commit SHA in
  the durable specification checkpoint.
- **FR-004**: The checkpoint MUST identify the waiting state as `awaiting_approval`, the phase as
  `specify`, and the approval gate as `spec`.
- **FR-005**: The visible GitHub writes used as verification evidence MUST be attributable to the
  configured dedicated App bot rather than a personal access token or unrelated identity.
- **FR-006**: The workflow MUST NOT expose App IDs, installation IDs, private-key contents, token
  values, or private-key paths in the specification, commit, issue comments, or checkpoint summary.
- **FR-007**: The workflow MUST stop after creating the specification approval checkpoint and MUST
  NOT create planning artifacts, implementation artifacts, a pull request, or a merge.
- **FR-008**: The waiting checkpoint MUST remain sufficient for a later status or restart-recovery
  check to reconstruct the same branch, commit, phase, and approval gate without repeating the
  completed specification phase.

### Key Entities

- **Dedicated App profile**: Host-owned configuration that selects the operator's dedicated GitHub
  App installation and bot identity; its secret values and filesystem locations are never part of
  the smoke-test artifact.
- **Specification checkpoint**: Durable issue state containing the waiting status, phase, gate,
  branch, commit SHA, phase ledger, assumptions, and validation evidence.
- **Smoke issue**: Disposable GitHub issue used to verify the App-authenticated handoff and later
  restart-recovery and cancellation behavior.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One remote issue branch exists at the same 40-character commit SHA recorded in the
  specification checkpoint.
- **SC-002**: The latest workflow checkpoint reports exactly one completed specify run, exactly one
  completed clarify scan, zero plan or implementation runs, and the `spec` approval gate.
- **SC-003**: All visible GitHub writes used by this smoke step are attributable to the configured
  dedicated App bot, with zero credential values or private-key paths exposed.
- **SC-004**: After the checkpoint is created, the workflow has produced zero plan files, task
  files, implementation changes, pull requests, or merges for this issue.
- **SC-005**: A later workflow-state read can recover the same issue branch, commit SHA, phase, and
  approval gate without creating a second specification commit.

## Assumptions

- The operator has already created, installed, and locally verified the dedicated `symphony-plus`
  GitHub App profile for this repository.
- The smoke issue is disposable and will be cancelled and closed by the operator after status and
  restart-recovery checks.
- App registration, permission changes, key rotation, and profile-file inspection are outside this
  specification; this smoke test validates observable use of the existing profile.
- Cancellation, issue closure, workspace cleanup, and remote branch deletion occur only after this
  approval checkpoint and are outside the work authorized in this run.
