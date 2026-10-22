# Tasks: Single Multi-Repository Service

**Input**: Design documents from `specs/gh-31-multi-repo-service/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required by the constitution for every behavior change. Each story begins with focused failing tests and ends with its targeted validation.

**Organization**: Tasks are grouped by user story so each increment remains independently testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes different files and has no dependency on an incomplete task
- **[Story]**: Maps the task to a user story from spec.md
- Every task includes exact file paths and requirement references

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish installation-local storage configuration and reusable test fixtures.

- [ ] T001 Add configurable project data-root accessors and registry-path defaults under ignored `elixir/tmp/symphony-plus/` per FR-004 and FR-019 in `elixir/lib/symphony_plus/config.ex` and `elixir/lib/symphony_plus/config/schema.ex`
- [ ] T002 [P] Add isolated workflow, registry, and multi-project fixture helpers without secret-bearing content in `elixir/test/support/test_support.exs` and `elixir/test/fixtures/`
- [ ] T003 [P] Add a regression assertion that the default registry location remains ignored and no machine-local registry is tracked in `elixir/test/symphony_plus/extensions_test.exs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build the single durable registry owner and isolated project runtime substrate required by every story.

**⚠️ CRITICAL**: No user-story implementation begins until this phase passes focused tests.

- [ ] T004 Write failing registry tests for versioned minimal records (`id` unique, `workflow_path` canonical absolute and unique, no workflow content/credentials), malformed/unknown envelopes, atomic interrupted writes, and idempotent concurrent mutations per FR-003–FR-005 and FR-014–FR-015 in `elixir/test/symphony_plus/project_registry_test.exs`
- [ ] T005 Implement the sole-authority `SymphonyPlus.ProjectRegistry` GenServer with versioned JSON loading, canonical identity, atomic same-directory temp-file sync/rename, serialized idempotent add/remove, and public `@spec`s in `elixir/lib/symphony_plus/project_registry.ex`
- [ ] T006 [P] Write failing runtime-supervision tests for states `unavailable | starting | active | stopping`, pairwise workspace-root validation, bounded non-secret reasons, and child failure isolation per FR-006–FR-007, FR-016, and FR-018 in `elixir/test/symphony_plus/project_runtime_test.exs`
- [ ] T007 Implement `SymphonyPlus.ProjectRuntimeSupervisor` and `SymphonyPlus.ProjectRuntime`, passing project identity and loaded workflow/config explicitly and retaining unavailable registrations for retry in `elixir/lib/symphony_plus/project_runtime_supervisor.ex` and `elixir/lib/symphony_plus/project_runtime.ex`
- [ ] T008 Refactor workflow loading and typed configuration to accept explicit project context instead of a mutable global workflow path while preserving `SymphonyPlus.Config` as the configuration boundary in `elixir/lib/symphony_plus/workflow_store.ex`, `elixir/lib/symphony_plus/workflow.ex`, and `elixir/lib/symphony_plus/config.ex`
- [ ] T009 Update OTP application startup so `ProjectRegistry` and `ProjectRuntimeSupervisor` own registration/runtime lifecycle before status and HTTP children in `elixir/lib/symphony_plus.ex`
- [ ] T010 Run focused foundational tests `mix test test/symphony_plus/project_registry_test.exs test/symphony_plus/project_runtime_test.exs test/symphony_plus/workspace_and_config_test.exs` from `elixir/` and retain the passing evidence in the implementation handoff

**Checkpoint**: Durable registry mutations and isolated runtime children are ready for story work.

---

## Phase 3: User Story 1 - Run One Service for All Projects (Priority: P1) 🎯 MVP

**Goal**: One service operates multiple project runtimes concurrently with isolated issue lifecycle and unified project-attributed status.

**Independent Test**: Register two valid workflows, run both under one service, observe project-attributed issue rows, and prove a failure/reload in one does not disrupt the other.

### Tests for User Story 1

- [ ] T011 [P] [US1] Write failing real-OTP tests for two active project orchestrators, aggregate concurrency, failure isolation, project-scoped reload/retry state, and workspace separation per FR-002, FR-006–FR-007, FR-016, and SC-003 in `elixir/test/symphony_plus/project_runtime_test.exs`
- [ ] T012 [P] [US1] Write failing projection tests requiring `project_id` on every issue/failure row and consistent aggregate counts across runtime status, API, and dashboard per FR-017 in `elixir/test/symphony_plus/orchestrator_status_test.exs` and `elixir/test/symphony_plus/runtime_status_test.exs`

### Implementation for User Story 1

- [ ] T013 [US1] Parameterize orchestrator, tracker, retry/quota/checkpoint, workspace, and agent-runner ownership by explicit project runtime context without weakening per-issue isolation in `elixir/lib/symphony_plus/orchestrator.ex`, `elixir/lib/symphony_plus/agent_runtime_supervisor.ex`, and `elixir/lib/symphony_plus/agent_runner.ex`
- [ ] T014 [US1] Aggregate project snapshots into one authoritative service projection with project-attributed issues, failures, and counts in `elixir/lib/symphony_plus/runtime_status.ex` and `elixir/lib/symphony_plus/status_dashboard.ex`
- [ ] T015 [US1] Adapt API/dashboard presenters and PubSub updates to consume aggregate project snapshots without consulting a singleton orchestrator in `elixir/lib/symphony_plus_web/presenter.ex`, `elixir/lib/symphony_plus_web/controllers/observability_api_controller.ex`, and `elixir/lib/symphony_plus_web/observability_pubsub.ex`
- [ ] T016 [US1] Add stable secret-safe project lifecycle and failure logs carrying `project_id` while retaining issue/session identifiers in `elixir/lib/symphony_plus/project_registry.ex`, `elixir/lib/symphony_plus/project_runtime.ex`, and `elixir/lib/symphony_plus/orchestrator.ex`
- [ ] T017 [US1] Run targeted multi-project lifecycle and status tests in `elixir/test/symphony_plus/project_runtime_test.exs`, `elixir/test/symphony_plus/orchestrator_status_test.exs`, and `elixir/test/symphony_plus/runtime_status_test.exs`

**Checkpoint**: The MVP operates multiple projects through one service and one status surface.

---

## Phase 4: User Story 2 - Start Before Adding a Project (Priority: P2)

**Goal**: Start successfully with an empty registry and expose a healthy empty service ready for configuration.

**Independent Test**: Start from an empty data root without a workflow argument and reach healthy CLI/API/dashboard state with no dispatch.

### Tests for User Story 2

- [ ] T018 [P] [US2] Write failing startup tests for zero registrations, no orchestrator dispatch, sub-10-second readiness contract, and last-project removal returning to the same state per FR-001, FR-020, and SC-001 in `elixir/test/symphony_plus/core_test.exs` and `elixir/test/symphony_plus/project_runtime_test.exs`
- [ ] T019 [P] [US2] Write failing LiveView/API tests for the healthy empty state and add-project affordance per FR-008 in `elixir/test/symphony_plus/live_e2e_test.exs`

### Implementation for User Story 2

- [ ] T020 [US2] Remove the boot-time workflow requirement and keep the service healthy with zero runtime children in `elixir/lib/symphony_plus.ex` and `elixir/lib/symphony_plus/cli.ex`
- [ ] T021 [US2] Render consistent zero-project state and onboarding guidance in terminal, JSON, and LiveView projections in `elixir/lib/symphony_plus/status_dashboard.ex`, `elixir/lib/symphony_plus_web/presenter.ex`, and `elixir/lib/symphony_plus_web/live/dashboard_live.ex`
- [ ] T022 [US2] Run targeted empty-startup and empty-dashboard tests in `elixir/test/symphony_plus/core_test.exs`, `elixir/test/symphony_plus/project_runtime_test.exs`, and `elixir/test/symphony_plus/live_e2e_test.exs`

**Checkpoint**: Fresh and post-removal empty installations are healthy and configurable.

---

## Phase 5: User Story 3 - Manage Projects from UI or CLI (Priority: P3)

**Goal**: Dashboard and CLI share identical add/list/remove validation and state through the running registry owner.

**Independent Test**: Add through LiveView, list through CLI, reject a duplicate, refuse busy removal, remove when idle through CLI, and see every result reflected without restart.

### Tests for User Story 3

- [ ] T023 [P] [US3] Write failing CLI contract tests for `projects list|add|remove`, table/JSON output, local-service-only mutations, exit semantics, duplicate add, busy removal, and legacy positional migration per FR-009–FR-013 and FR-019 in `elixir/test/symphony_plus/cli_test.exs`
- [ ] T024 [P] [US3] Write failing local management API tests for project endpoints, stable result/error codes, CSRF browser behavior, and secret-safe errors per `contracts/dashboard-api.md` in `elixir/test/symphony_plus/project_management_api_test.exs`
- [ ] T025 [P] [US3] Write failing LiveView tests for explicit workflow-path submission, registered-project listing, project state, duplicate feedback, removal refusal, and PubSub refresh per FR-008 and FR-011–FR-013 in `elixir/test/symphony_plus/live_e2e_test.exs`

### Implementation for User Story 3

- [ ] T026 [US3] Implement CLI parsing and local HTTP client behavior for `projects list|add|remove`, `--data-root`, `--service-url`, `--format`, and legacy workflow migration in `elixir/lib/symphony_plus/cli.ex`
- [ ] T027 [US3] Add `POST /api/v1/projects` and `DELETE /api/v1/projects/:project_id` routes with stable contract responses and one registry mutation path in `elixir/lib/symphony_plus_web/router.ex` and `elixir/lib/symphony_plus_web/controllers/observability_api_controller.ex`
- [ ] T028 [US3] Implement the Projects LiveView section, explicit local workflow-path add form, idle-only removal, actionable results, and project transition refreshes in `elixir/lib/symphony_plus_web/live/dashboard_live.ex` and `elixir/lib/symphony_plus_web/presenter.ex`
- [ ] T029 [US3] Enforce canonical workflow validation, workspace-root collision rejection, active/retrying/quota-waiting/blocked removal refusal, and non-destructive idle removal in `elixir/lib/symphony_plus/project_registry.ex` and `elixir/lib/symphony_plus/project_runtime.ex`
- [ ] T030 [US3] Run targeted CLI, API, LiveView, registry concurrency, and removal tests in `elixir/test/symphony_plus/cli_test.exs`, `elixir/test/symphony_plus/project_management_api_test.exs`, `elixir/test/symphony_plus/live_e2e_test.exs`, and `elixir/test/symphony_plus/project_registry_test.exs`

**Checkpoint**: Both operator interfaces manage one authoritative live registry with identical semantics.

---

## Phase 6: User Story 4 - Preserve Local Project Configuration (Priority: P4)

**Goal**: Persist minimal local registration records atomically, restore them independently, and recover invalid workflows automatically.

**Independent Test**: Persist multiple registrations, restart, isolate malformed/missing workflows, repair one without restart, simulate unwritable/interrupted storage, and verify no tracked or secret-bearing data changes.

### Tests for User Story 4

- [ ] T031 [P] [US4] Write failing restart/recovery tests for 100% valid restoration, retained invalid registrations, polling-cadence revalidation, automatic activation after repair, and transition-only logging per FR-006, FR-021, and SC-004 in `elixir/test/symphony_plus/project_runtime_test.exs`
- [ ] T032 [P] [US4] Write failing persistence fault tests for missing/empty/unreadable/malformed/unknown-version registry files, unwritable directories, interrupted temp files, and unchanged last-good state per FR-015 and SC-006 in `elixir/test/symphony_plus/project_registry_test.exs`
- [ ] T033 [P] [US4] Write failing secret/data-minimization tests proving registry, CLI, API, dashboard, and logs exclude workflow content, credentials, private keys, and raw exceptions per FR-005, FR-018, and SC-007 in `elixir/test/symphony_plus/project_registry_test.exs` and `elixir/test/symphony_plus/documentation_contract_test.exs`

### Implementation for User Story 4

- [ ] T034 [US4] Complete startup restoration and periodic unavailable-project validation so repaired workflows activate without re-registration or restart in `elixir/lib/symphony_plus/project_registry.ex` and `elixir/lib/symphony_plus/project_runtime.ex`
- [ ] T035 [US4] Harden last-good registry retention and bounded safe diagnostics for malformed, unreadable, unsupported, and interrupted persistence states in `elixir/lib/symphony_plus/project_registry.ex`
- [ ] T036 [US4] Run targeted persistence, restart, recovery, and secret-safety tests in `elixir/test/symphony_plus/project_registry_test.exs`, `elixir/test/symphony_plus/project_runtime_test.exs`, and `elixir/test/symphony_plus/documentation_contract_test.exs`

**Checkpoint**: Installation-local configuration survives restart and temporary project failures without corruption or disclosure.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Align normative/operator documentation, exercise complete migrations and lifecycle scenarios, and pass all repository gates.

- [ ] T037 [P] Update the normative service model and multi-project lifecycle behavior required by Constitution I in `SPEC.md`
- [ ] T038 [P] Document zero-project startup, data-root/registry location, legacy positional migration, project commands, dashboard management, recovery, and safety boundaries in `README.md`, `elixir/README.md`, and `elixir/docs/agent-installation.md`
- [ ] T039 [P] Update stable project lifecycle event names and required project context in `elixir/docs/logging.md`
- [ ] T040 Execute every scenario in `specs/gh-31-multi-repo-service/quickstart.md`, including two-project operation, duplicate mutation, restart, invalid-workflow recovery, unwritable storage, busy removal, and final empty state
- [ ] T041 Review all public functions added under `elixir/lib/` for adjacent `@spec`s and run formatter, focused tests, and `git diff --check`
- [ ] T042 Run the full constitution gate with `make -C elixir all` and record formatting, public-spec, Credo, coverage, and Dialyzer evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories.
- **US1 (Phase 3)**: First functional increment and MVP; depends on Foundational.
- **US2 (Phase 4)**: Depends on Foundational snapshot support; may proceed after T014 establishes aggregate projections.
- **US3 (Phase 5)**: Depends on registry mutations from Foundational and service projections from US1/US2.
- **US4 (Phase 6)**: Depends on Foundational persistence/runtime behavior; its tests may be prepared in parallel with US2/US3 after Phase 2.
- **Polish (Phase 7)**: Depends on all selected stories.

### User Story Dependencies

- **US1 (P1)**: No other story dependency; supplies the multi-project MVP.
- **US2 (P2)**: Uses US1 aggregate projections but is independently validated with no projects.
- **US3 (P3)**: Uses the foundational registry and US1/US2 status surfaces; its add/list/remove flow is independently testable.
- **US4 (P4)**: Uses the foundational registry/runtime and independently validates durability/recovery.

### Within Each User Story

- Write each listed test first and retain its failing signal before implementation.
- Complete state/model ownership before projections or interfaces that consume it.
- Complete implementation before the story's targeted validation task.
- Do not mark a story complete until its independent test passes with real OTP processes where applicable.

### Parallel Opportunities

- T002 and T003 can run in parallel after T001's configuration shape is understood.
- T004 and T006 can be authored in parallel before T005/T007 implementation.
- T011 and T012, T018 and T019, T023–T025, and T031–T033 are parallel test-authoring groups because they primarily touch distinct test files.
- US2 and US4 can proceed in parallel after the foundational and aggregate snapshot contracts stabilize.
- T037–T039 documentation updates can run in parallel after behavior and terminology stabilize.

---

## Parallel Example: User Story 3

```text
Task T023: CLI command and migration contract tests in elixir/test/symphony_plus/cli_test.exs
Task T024: Local management API contract tests in elixir/test/symphony_plus/project_management_api_test.exs
Task T025: LiveView project-management requirements in elixir/test/symphony_plus/live_e2e_test.exs
```

---

## Implementation Strategy

### MVP First

1. Complete Setup and Foundational phases.
2. Complete US1 and validate two isolated projects under one service.
3. Stop and review the service/runtime ownership boundary before adding interfaces.

### Incremental Delivery

1. Add healthy zero-project startup (US2).
2. Add shared CLI/UI management (US3).
3. Complete persistence fault recovery and secret-safety hardening (US4).
4. Update all contracts/docs, execute the quickstart, and pass `make -C elixir all`.

## Notes

- `[P]` tasks change different files or are independent test-authoring work.
- Story labels provide traceability to the approved specification.
- Custom checklist markers are reviewer-owned and are not changed during implementation.
- Mark each task `[X]` only after its work and targeted validation succeed.
