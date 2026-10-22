# Feature Specification: Single Multi-Repository Service

**Feature Branch**: `symphony-plus/gh-31-multi-repo-service`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "Start Symphony Plus once for all configured repositories, allow startup with no repositories, add repositories from the UI or CLI by selecting a workflow file, and persist the local repository list in an uncommitted cache location."

## Clarifications

### Session 2026-10-22

- Q: When a registered project's workflow file is missing or invalid at startup, how should Symphony Plus preserve that registration? → A: Retain and retry: keep the registration, mark only that project unavailable with an actionable reason, and automatically activate it after the workflow becomes valid again.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run One Service for All Projects (Priority: P1)

As an operator, I start Symphony Plus once and have that service operate every registered project so I do not need a separate process or port for each repository.

**Why this priority**: A single long-running service is the core value of the feature and removes duplicated processes, ports, and operational state.

**Independent Test**: Register two valid repository workflow files, start one service, and observe that both projects are polled and their issue work remains isolated while a single status surface reports both.

**Acceptance Scenarios**:

1. **Given** two registered projects with valid workflow files, **When** the operator starts Symphony Plus, **Then** one service activates both projects without requiring a project-specific startup process or port.
2. **Given** active work in two projects, **When** the operator views service status, **Then** each issue is associated with its project and all issues appear in the same status surface.
3. **Given** one project fails to load or operate, **When** another registered project remains valid, **Then** the valid project continues operating and the failed project has an actionable, project-scoped status.

---

### User Story 2 - Start Before Adding a Project (Priority: P2)

As a new operator, I can start Symphony Plus with no registered projects and use the running service to configure the first project.

**Why this priority**: Empty startup removes the current boot-time dependency on a workflow file and enables dashboard-led onboarding.

**Independent Test**: Start with an empty local registry and confirm the service reaches a healthy empty state that explains how to add a project.

**Acceptance Scenarios**:

1. **Given** no registered projects, **When** the operator starts Symphony Plus, **Then** startup succeeds and the service reports a healthy empty state.
2. **Given** the healthy empty state, **When** the operator opens the dashboard, **Then** the dashboard presents an add-project action and no issue work is dispatched until a valid project is added.

---

### User Story 3 - Manage Projects from UI or CLI (Priority: P3)

As an operator, I can add and remove a project through either the dashboard or command line by selecting its repository-owned workflow file.

**Why this priority**: Both interaction paths are explicitly requested and must operate on the same durable project registry.

**Independent Test**: Add a project using the UI, observe it from the CLI, remove it using the CLI, and confirm the UI reflects the same registry state without restarting the service.

**Acceptance Scenarios**:

1. **Given** a running service, **When** the operator selects a valid workflow file in the dashboard, **Then** the project is registered, becomes visible, and begins operating without a service restart.
2. **Given** a valid workflow file, **When** the operator adds it through the CLI, **Then** the same project entry and activation behavior are visible in the dashboard.
3. **Given** an already registered workflow file, **When** the operator attempts to add it again through either interface, **Then** no duplicate project is created and the operator receives a clear result.
4. **Given** a registered project with no active issue work, **When** the operator removes it through either interface, **Then** it is no longer polled and remains absent after restart.
5. **Given** a registered project with active issue work, **When** removal is requested, **Then** removal is refused with an explanation that active work must finish or be cancelled first.

---

### User Story 4 - Preserve Local Project Configuration (Priority: P4)

As an operator, I want registered projects to survive service restarts without committing machine-specific paths or credentials to source control.

**Why this priority**: Persistence makes single-start operation practical while protecting local-only configuration from accidental publication.

**Independent Test**: Register projects, restart the service from the same Symphony Plus installation, and confirm the registry is restored from an ignored local data location without modifying tracked files.

**Acceptance Scenarios**:

1. **Given** one or more registered projects, **When** the service restarts, **Then** it restores the same registrations before beginning normal project operation.
2. **Given** a project registration change, **When** persistence succeeds, **Then** no tracked repository file is modified.
3. **Given** registry persistence cannot be completed, **When** an add or remove operation is attempted, **Then** the operation fails without exposing a partially updated durable registry and the operator receives an actionable error.
4. **Given** a registered project's workflow file is missing or invalid at startup, **When** the service restores the registry, **Then** it retains the registration, marks only that project unavailable with an actionable reason, and automatically activates it after the workflow becomes valid again.

### Edge Cases

- A selected path does not exist, is not a regular readable file, or is not a valid workflow definition.
- Two paths resolve to the same workflow file through relative paths, symbolic links, or path aliases.
- Two registered workflows would resolve to the same workspace root or otherwise violate workspace isolation.
- A registered workflow is moved, deleted, or becomes invalid between service restarts or during operation.
- One project's workflow changes while other projects have active work.
- The registry file is missing, empty, unreadable, malformed, or left with an interrupted write.
- Multiple UI or CLI requests try to add or remove the same project concurrently.
- A project is removed while it has queued retries, quota waits, blocked checkpoints, or active sessions.
- The dashboard is disabled but CLI project management remains available.
- A workflow file or local registry contains a secret-like value; status and errors must not reveal it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The service MUST start successfully with zero registered projects and expose a healthy empty state.
- **FR-002**: One running service MUST own and operate all registered projects through one authoritative service-level runtime.
- **FR-003**: Each registered project MUST be defined by an explicit absolute path to a repository-owned workflow file.
- **FR-004**: The service MUST maintain a durable local registry of registered projects outside tracked source files, and the repository MUST ignore the selected registry location.
- **FR-005**: The registry MUST persist only the minimum project identity and workflow-path information required to restore registrations; it MUST NOT copy workflow content or store credentials.
- **FR-006**: The service MUST restore registered projects on startup and activate every valid entry independently.
- **FR-007**: A failure in one registered project MUST NOT prevent startup or continued operation of other valid registered projects.
- **FR-008**: The dashboard MUST list registered projects, distinguish project-scoped status and issues, show an empty state, and provide an action for adding a project by selecting or supplying a workflow file.
- **FR-009**: The CLI MUST provide commands to list, add, and remove registered projects using the same durable registry and validation rules as the dashboard.
- **FR-010**: Adding a project through either interface MUST validate the workflow file, canonicalize its path, reject duplicates, and reject configurations that violate workspace boundaries before persisting or activating it.
- **FR-011**: A successfully added project MUST become active without restarting the service, and both UI and CLI views MUST reflect the same registry state.
- **FR-012**: Removing a project through either interface MUST stop future polling and remove the durable registration without deleting its repository, workflow file, issue workspaces, or history.
- **FR-013**: The service MUST refuse project removal while that project owns active, retrying, quota-waiting, or blocked issue work and MUST explain how the operator can make removal safe.
- **FR-014**: Registration mutations MUST be serialized by one authoritative owner and MUST be idempotent under duplicate or concurrent requests.
- **FR-015**: Registry writes MUST be atomic so interruption cannot expose a partially written registry as valid state.
- **FR-016**: Dynamic workflow reload MUST remain project-scoped; reloading or rejecting one workflow MUST NOT change another project's effective configuration.
- **FR-017**: Runtime status projections, logs, dashboard rows, and machine-readable status MUST identify the owning project for every project-scoped issue or failure.
- **FR-018**: Project operations and diagnostics MUST avoid exposing workflow contents, credentials, private keys, or other secrets.
- **FR-019**: Existing operators who provide a workflow path at startup MUST receive a documented migration path into the project registry rather than silently creating divergent service modes.
- **FR-020**: Removing or disabling all projects MUST return the running service to the same healthy empty state as a fresh installation.
- **FR-021**: If a registered workflow file is missing or invalid at startup, the service MUST retain the registration, mark only that project unavailable with an actionable reason, and automatically activate it after the workflow becomes valid again without requiring re-registration or restart.

### Key Entities

- **Project Registration**: A durable local record identifying one managed project by a stable identifier and the canonical absolute path of its repository-owned workflow file.
- **Project Runtime**: The current activation and health state for one registration, including its effective workflow, tracker scope, issue lifecycle state, and project-scoped failure reason.
- **Project Registry**: The service-level collection of project registrations, with atomic persistence and one authoritative mutation owner.
- **Service Runtime**: The single process-level owner that coordinates the registry, project runtimes, shared status surfaces, and aggregate resource limits.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can start the service with no projects and reach a healthy empty dashboard or CLI status in under 10 seconds under normal local conditions.
- **SC-002**: An operator can register a valid project through either UI or CLI and see it begin normal polling without restarting the service.
- **SC-003**: One service can operate at least 10 registered projects concurrently while preserving project attribution and per-issue workspace isolation.
- **SC-004**: After any normal restart, 100% of successfully persisted project registrations are restored, or each unrestorable project is reported separately without preventing other projects from operating.
- **SC-005**: Repeating the same add or remove request produces no duplicate registration, partial registry state, or unintended deletion in 100% of acceptance tests.
- **SC-006**: Invalid workflow selection, conflicting workspace configuration, registry corruption, and one-project reload failure each produce an actionable project-scoped result without terminating healthy project runtimes.
- **SC-007**: Adding or removing a project changes no tracked source file and exposes no credential or workflow content in the registry, dashboard, CLI output, or logs.
- **SC-008**: UI and CLI project lists agree on project identity, workflow path, and current state after every successful registry mutation.

## Assumptions

- This feature targets one trusted local operator and one Symphony Plus installation, not a multi-tenant remote control plane.
- Each project continues to own its policy and tracker configuration in its own workflow file; the service-level registry does not duplicate that policy.
- A project's workflow file path is the canonical uniqueness key after filesystem path resolution.
- Aggregate process resource limits may be shared, but issue eligibility, retries, checkpoints, workflow reload, and workspaces remain project-scoped.
- Project removal is intentionally conservative and never deletes repositories or issue workspaces.
- The UI may use a browser-supported file/path selection interaction appropriate to a locally hosted service; exact widget mechanics are an implementation decision so long as the resulting path is explicit and validated.

## Out of Scope

- Remote multi-user authentication, authorization, or hosted multi-tenancy.
- Synchronizing the local project registry between machines.
- Copying or generating repository workflow files as part of registration.
- Deleting repositories, workflows, workspaces, branches, or issue history when a project is removed.
- Combining multiple repository workflows into one shared policy document.
