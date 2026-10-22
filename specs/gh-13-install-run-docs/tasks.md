# Tasks: Install and Run Documentation

**Input**: Design documents from `specs/gh-13-install-run-docs/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/documentation-surfaces.md, quickstart.md

**Tests**: Validation is documentation-focused: inspect checked-in commands and paths, audit links and repeated snippets, run `git diff --check`, and run `make -C elixir all`.

**Organization**: Tasks are grouped by user story so each documentation outcome can be implemented and reviewed independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it affects a different file and has no dependency on an incomplete task
- **[Story]**: Maps the task to a user story in `spec.md`
- Every task names the exact file or bounded file set it changes or validates

## Phase 1: Setup (Documentation Audit)

**Purpose**: Establish the checked-in command and path evidence used by every story.

- [X] T001 Audit supported source setup, build, validation, generated launcher, safe GitHub launcher, and workflow paths against `elixir/README.md`, `elixir/Makefile`, `elixir/mix.exs`, `elixir/scripts/run-github`, and `.symphony-plus/WORKFLOW.md`; record any required documentation corrections in the relevant story task before editing

---

## Phase 2: Foundational (Canonical Procedure)

**Purpose**: Make the canonical detailed generic procedure accurate before shorter surfaces reference it.

**⚠️ CRITICAL**: Complete this phase before updating the root or agent-facing summaries.

- [X] T002 Reconcile the canonical source-install and generic-run procedure in `elixir/README.md` with FR-004 and FR-007, including prerequisites, the `elixir/` starting directory, ordered `mise`/Mix commands, an explicit workflow path, generated-launcher expectations, and a distinct route to GitHub App onboarding

**Checkpoint**: The detailed generic procedure is authoritative and ready to be summarized elsewhere.

---

## Phase 3: User Story 1 - Human Quick Start (Priority: P1) 🎯 MVP

**Goal**: Let a human arriving at the repository copy an ordered source-install and generic-run sequence and find the separate GitHub onboarding path.

**Independent Test**: Read only `README.md`; verify a clean-checkout reader can identify prerequisites, enter `elixir/`, prepare the supported toolchain, install dependencies, build, run with an explicit workflow path, recognize startup, and route GitHub orchestration to focused guidance.

- [X] T003 [US1] Add a concise source-install and generic-run quick start to `README.md` that satisfies FR-001 through FR-003 and links directly to `elixir/README.md`, `elixir/docs/agent-installation.md`, and `.symphony-plus/README.md`
- [X] T004 [US1] Review the completed `README.md` flow against User Story 1 acceptance scenarios and SC-001, SC-002, and SC-005, correcting any undocumented directory transition or ambiguous execution-mode wording in `README.md`

**Checkpoint**: User Story 1 is independently usable from the root README.

---

## Phase 4: User Story 2 - Agent-Operable Setup (Priority: P2)

**Goal**: Give coding agents a safe, direct route to canonical setup, build, validation, generic-run, and GitHub orchestration guidance.

**Independent Test**: Read `elixir/AGENTS.md`; verify an agent can identify the expected directory and commands, follow the generic and GitHub guides, and cannot reasonably infer that credentials belong in an issue workspace.

- [X] T005 [US2] Add an agent-facing install, build, validation, and launch command summary with explicit working-directory expectations to `elixir/AGENTS.md`, linking generic detail to `elixir/README.md` and GitHub onboarding to `elixir/docs/agent-installation.md`
- [X] T006 [US2] State the safe GitHub launcher, source-checkout startup boundary, host-side credential boundary, and dedicated issue-workspace boundary in `elixir/AGENTS.md` without duplicating the full onboarding runbook

**Checkpoint**: User Story 2 is independently discoverable and safe from agent-facing guidance.

---

## Phase 5: User Story 3 - Consistent Documentation Surfaces (Priority: P3)

**Goal**: Keep one canonical command sequence while ensuring focused GitHub guides and summaries do not conflict or omit safety-critical distinctions.

**Independent Test**: Compare all five in-scope documentation surfaces; verify command order, working directories, workflow paths, mode labels, link destinations, credential handling, and workspace boundaries agree.

- [X] T007 [P] [US3] Audit and correct only command, cross-link, or safety-boundary inconsistencies in `.symphony-plus/README.md` while preserving repository-specific self-hosting values
- [X] T008 [P] [US3] Audit and correct only command, cross-link, or safety-boundary inconsistencies in `elixir/docs/agent-installation.md` while preserving its role as the end-to-end GitHub onboarding authority
- [X] T009 [US3] Compare `README.md`, `elixir/README.md`, `elixir/AGENTS.md`, `.symphony-plus/README.md`, and `elixir/docs/agent-installation.md` against `specs/gh-13-install-run-docs/contracts/documentation-surfaces.md`; resolve conflicting command order, directory assumptions, workflow paths, launch-mode labels, or canonical-owner claims in the owning documentation file

**Checkpoint**: All documentation surfaces are consistent and point to their canonical owners.

---

## Phase 6: Polish & Cross-Cutting Validation

**Purpose**: Prove link, path, scope, safety, and repository quality requirements across all stories.

- [X] T010 Validate every changed repository-relative Markdown link and every named checked-in or generated executable path across `README.md`, `elixir/README.md`, `elixir/AGENTS.md`, `.symphony-plus/README.md`, and `elixir/docs/agent-installation.md`
- [X] T011 Search `README.md`, `elixir/README.md`, `elixir/AGENTS.md`, `.symphony-plus/README.md`, and `elixir/docs/agent-installation.md` for unresolved placeholders, literal secrets, unsafe credential-copying guidance, and ambiguous generic-versus-GitHub launch examples; correct findings in the owning Markdown file
- [X] T012 Run `git diff --check` and the scenarios in `specs/gh-13-install-run-docs/quickstart.md`, then record the validation outcome for handoff
- [X] T013 Run `make -C elixir all` and review the final diff for unrelated changes, generated artifacts, runtime/configuration changes, `SPEC.md` changes, and constitution violations

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependency; establishes command/path evidence.
- **Foundational (Phase 2)**: Depends on T001 and blocks summary updates.
- **User Story 1 (Phase 3)**: Depends on T002 so the root quick start summarizes the canonical procedure.
- **User Story 2 (Phase 4)**: Depends on T002; otherwise independently reviewable from User Story 1.
- **User Story 3 (Phase 5)**: T007 and T008 may run after T002; T009 depends on T003 and T005 through T008 so it can reconcile the complete surface set.
- **Polish (Phase 6)**: Depends on all selected user stories.

### User Story Dependencies

- **User Story 1 (P1)**: Depends only on the canonical procedure and is the MVP.
- **User Story 2 (P2)**: Depends only on the canonical procedure; it can be implemented independently of User Story 1.
- **User Story 3 (P3)**: Its focused-guide audits can start after the canonical procedure, but its final cross-surface comparison depends on User Stories 1 and 2.

### Parallel Opportunities

- T003–T004 and T005–T006 affect different files and can be assigned in parallel after T002, while tasks within each pair remain sequential.
- T007 and T008 are explicitly parallel because they audit different focused guides.
- Validation tasks remain sequential to ensure corrections precede the full gate.

## Parallel Example: User Story 3

```text
Task T007: Audit `.symphony-plus/README.md` for command, link, and safety consistency.
Task T008: Audit `elixir/docs/agent-installation.md` for command, link, and safety consistency.
```

## Implementation Strategy

### MVP First (User Story 1)

1. Complete T001–T002 to establish the canonical sequence.
2. Complete T003–T004 to deliver a root-level human quick start.
3. Validate the User Story 1 independent test before expanding agent and maintainer surfaces.

### Incremental Delivery

1. Canonical procedure → trusted source of command truth.
2. User Story 1 → human quick start and mode routing.
3. User Story 2 → agent command discovery and safety boundaries.
4. User Story 3 → focused-guide reconciliation and zero-conflict audit.
5. Cross-cutting validation → links, paths, secrets, whitespace, and full Elixir quality gate.

## Notes

- Custom checklist markers in `checklists/documentation.md` are reviewer-owned and are not implementation completion markers.
- Keep `SPEC.md`, runtime code, configuration semantics, and release artifacts unchanged.
- Preserve one detailed owner per procedure; summaries should link instead of reproducing incomplete onboarding steps.
- Mark each task `[X]` only after its described edit or validation is complete.
