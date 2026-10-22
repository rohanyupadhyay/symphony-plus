# Feature Specification: Install and Run Documentation

**Feature Branch**: `symphony/gh-13-install-run-docs`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "Add the commands to install and run Symphony Plus in the README and any other places where a human and an agent can and is likely to read."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Human quick start (Priority: P1)

As a prospective operator arriving at the repository, I can find a concise, copyable sequence that installs the supported dependencies, builds Symphony Plus, and starts it with a workflow file.

**Why this priority**: The root documentation is the primary discovery surface, and a complete quick start removes the need to navigate multiple guides before evaluating the project.

**Independent Test**: Starting from a clean checkout on a supported host, a reader can follow the root documentation to identify prerequisites, complete installation, and start Symphony Plus without consulting undocumented steps.

**Acceptance Scenarios**:

1. **Given** a reader opens the root README, **When** they look for installation instructions, **Then** they find the prerequisite and setup commands in an ordered, copyable block.
2. **Given** setup is complete, **When** the reader continues through the quick start, **Then** they find a command that starts Symphony Plus with an explicit workflow path and learn what successful startup exposes.
3. **Given** a reader needs GitHub issue orchestration rather than the generic workflow, **When** they inspect the quick start, **Then** they are directed to the GitHub App setup and repository onboarding guides instead of being led to use an incomplete generic command.

---

### User Story 2 - Agent-operable setup (Priority: P2)

As a coding agent onboarding or maintaining a repository, I can find the same canonical install, build, validation, and run commands in agent-facing guidance, including the working-directory and workflow-path expectations.

**Why this priority**: Agents need unambiguous commands and path boundaries to perform setup safely and consistently, but this depends on the human-facing command sequence being established first.

**Independent Test**: An agent reading repository guidance can identify the correct source directory, supported toolchain setup, build command, generic launch command, GitHub launch command, and the focused guide for full repository onboarding.

**Acceptance Scenarios**:

1. **Given** an agent reads the repository's agent-facing guidance, **When** it searches for installation and execution instructions, **Then** it finds or is directly linked to the canonical commands without inferring missing steps.
2. **Given** an agent is configuring GitHub issue orchestration, **When** it follows the agent-facing guidance, **Then** it is directed to the App-authenticated launcher and installation runbook rather than exposing credentials or launching from an issue workspace.

---

### User Story 3 - Consistent documentation surfaces (Priority: P3)

As a maintainer, I can update one clearly identified canonical command sequence and verify that shorter references elsewhere neither conflict with nor omit safety-critical distinctions.

**Why this priority**: Repeated command snippets become harmful when they drift, so documentation must state which guide is authoritative and keep cross-references consistent.

**Independent Test**: A review of all prominent human- and agent-facing documentation finds no conflicting install, build, or launch commands and finds an explicit path to the detailed operational guides.

**Acceptance Scenarios**:

1. **Given** the relevant documentation surfaces are reviewed together, **When** duplicate command sequences are compared, **Then** their prerequisites, working directories, and command order agree.
2. **Given** a surface intentionally provides only a summary, **When** a reader needs the complete procedure, **Then** a direct repository-relative link identifies the canonical detailed guide.

### Edge Cases

- A reader already has the supported runtime installed; the documentation distinguishes required verification from repeatable dependency setup without implying destructive reinstallation.
- A reader wants the generic local workflow while another wants GitHub issue orchestration; the two launch paths are labeled so they cannot reasonably be confused.
- A command is copied from the repository root rather than the implementation directory; every command sequence states or performs the required directory change.
- A target repository has not yet installed its repository-owned `.symphony/WORKFLOW.md`; the quick start points to onboarding instead of presenting a path that silently cannot work.
- Platform-specific prebuilt binaries and source installation coexist; the documentation makes clear which prerequisites apply to each path.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The root README MUST include a prominently discoverable source-install quick start with ordered, copyable commands for obtaining the repository, entering the implementation directory, preparing the supported toolchain, installing dependencies, and building the executable.
- **FR-002**: The root README MUST include a copyable generic run command that uses an explicit workflow-file path and states the expected working directory.
- **FR-003**: The root README MUST distinguish the generic local run path from the App-authenticated GitHub issue orchestration path and link to the complete onboarding and security guidance.
- **FR-004**: The Elixir implementation README MUST remain the canonical detailed source-install and generic-run reference, with its sequence consistent with the root quick start.
- **FR-005**: Agent-facing repository guidance MUST state or directly link to the canonical install, build, validation, and launch commands, including the safe GitHub launcher where applicable.
- **FR-006**: The AI-agent installation runbook MUST remain the canonical end-to-end GitHub onboarding procedure and MUST be linked from shorter agent-facing guidance rather than duplicated incompletely.
- **FR-007**: Every documented command sequence MUST identify its prerequisites, starting directory or directory-changing command, workflow-path expectation, and intended execution mode.
- **FR-008**: Documentation MUST preserve the credential and workspace boundaries in the normative specification and constitution: credentials remain host-side, normal operation starts from the Symphony Plus source checkout, and issue work runs only in dedicated issue workspaces.
- **FR-009**: Repository-relative documentation links and command references MUST resolve to existing files and executables.
- **FR-010**: The change MUST NOT alter runtime behavior, configuration semantics, release artifacts, or the normative product contract.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new reader can locate a complete source-install and generic-run sequence from the root README within one navigation step.
- **SC-002**: All commands in the root quick start can be copied in order from a clean checkout without an undocumented working-directory transition.
- **SC-003**: A documentation audit finds zero conflicting install, build, or launch commands across the root README, Elixir README, agent guidance, self-hosting guide, and AI-agent installation runbook.
- **SC-004**: Every prominent install/run surface links directly to the appropriate detailed guide, with zero broken repository-relative links in the changed documentation.
- **SC-005**: Reviewers can classify every launch example as either generic local execution or App-authenticated GitHub orchestration without relying on external context.

## Assumptions

- Source installation is the primary quick-start path; prebuilt release binaries remain documented as an alternative in the Elixir README.
- `mise` remains the supported toolchain manager, and the checked-in Elixir README defines the current canonical command spelling.
- The root README, `elixir/README.md`, `elixir/AGENTS.md`, `.symphony/README.md`, and `elixir/docs/agent-installation.md` are the most likely human- and agent-facing surfaces for this issue.
- The existing self-hosting guide already contains repository-specific launch commands; this work needs to verify its consistency rather than replace its operator-specific values.
- No changes to `SPEC.md` are required because this feature improves discoverability without changing product behavior or contracts.
