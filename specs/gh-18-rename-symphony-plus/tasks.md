---

description: "Implementation tasks for the Symphony Plus repository-wide rename"
---

# Tasks: Rename Symphony to Symphony Plus

**Input**: Design documents from `specs/gh-18-rename-symphony-plus/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/naming-contract.md, quickstart.md

**Tests**: Required by FR-010, SC-004, and Constitution V. Test tasks precede the corresponding implementation work and must first demonstrate the legacy contract.

**Organization**: Tasks are grouped by user story so operator interfaces, documentation, and internal identities remain independently reviewable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes different files and has no dependency on unfinished tasks
- **[Story]**: Maps the task to a feature user story
- Every task names its repository path or explicit live metadata target

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish a deterministic rename inventory and test-first guardrails before changing contracts.

- [X] T001 Create a classified whole-word legacy-name audit script covering maintained files and paths, excluding VCS/dependency/build output and accepting only `upstream`, `historical`, or `immutable_external` entries, in `elixir/scripts/audit_product_identity.exs` and `elixir/test/fixtures/product_identity_allowlist.txt`
- [X] T002 [P] Add failing naming-contract assertions for canonical display, slug, module, application, environment, command, path, branch, label, and release values in `elixir/test/symphony_elixir/product_identity_test.exs`
- [X] T003 [P] Add failing release-workflow assertions for `symphony-plus` artifacts, titles, executable output, and removed legacy aliases in `elixir/test/symphony_elixir/release_contract_test.exs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Atomically establish canonical project identities needed by every user story.

**⚠️ CRITICAL**: Complete this phase before operator, documentation, or maintained-code story work.

- [X] T004 Rename the Mix application, release, escript identity, package metadata, aliases, and environment prefixes to `:symphony_plus`, `SymphonyPlus`, and `SYMPHONY_PLUS_*` in `elixir/mix.exs`, `elixir/config/config.exs`, `elixir/config/runtime.exs`, and `elixir/Makefile`
- [X] T005 Rename module roots and source directories from `SymphonyElixir`/`SymphonyElixirWeb` to `SymphonyPlus`/`SymphonyPlusWeb` in `elixir/lib/symphony_elixir.ex`, `elixir/lib/symphony_elixir/`, and `elixir/lib/symphony_elixir_web/`, updating all compile-time references atomically
- [X] T006 Rename test namespaces, support modules, fixture paths, and application references to the canonical identities in `elixir/test/symphony_elixir/`, `elixir/test/support/`, and `elixir/test/test_helper.exs`
- [X] T007 Run the focused identity and compilation checks from T002-T006 and correct only migration-caused failures in `elixir/test/symphony_plus/product_identity_test.exs`, `elixir/test/symphony_plus/release_contract_test.exs`, `elixir/lib/symphony_plus/`, and `elixir/lib/symphony_plus_web/`

**Checkpoint**: The application compiles and has one canonical internal product identity with no forwarding modules or aliases.

---

## Phase 3: User Story 1 - Operate the Renamed Product (Priority: P1) 🎯 MVP

**Goal**: Operators build, start, configure, label, and control the product exclusively through Symphony Plus interfaces.

**Independent Test**: Follow the build-to-first-managed-issue path using only `symphony-plus`, `.symphony-plus/`, the `symphony-plus` label, `/symphony-plus`, and `symphony-plus/` branches; every removed legacy form is rejected.

### Tests for User Story 1

- [X] T008 [P] [US1] Add failing CLI and launcher tests for `bin/symphony-plus`, help/banner text, GitHub App subcommands, and absence of `bin/symphony` in `elixir/test/symphony_plus/cli_test.exs` and `elixir/test/symphony_plus/scripts/run_github_test.exs`
- [X] T009 [P] [US1] Add failing GitHub workflow tests for the `symphony-plus` eligibility label, `/symphony-plus` grammar, rendered guidance, cancellation, and `symphony-plus/` branches in `elixir/test/symphony_plus/github/issues_test.exs`, `elixir/test/symphony_plus/github/workflow_control_test.exs`, and `elixir/test/symphony_plus/github/branch_test.exs`
- [X] T010 [P] [US1] Add failing persisted-path and lifecycle tests for renamed quota waits, profiles, logs, default workspace roots, startup/restart/reconciliation/cancellation/cleanup, automatic review, and merge-queue handoff in `elixir/test/symphony_plus/` and `elixir/test/support/`

### Implementation for User Story 1

- [X] T011 [US1] Rename executable creation, startup dispatch, GitHub App setup/verify commands, launcher variables, and stable user messages without aliases in `elixir/lib/symphony_plus/cli.ex`, `elixir/scripts/run-github`, and `elixir/bin/`
- [X] T012 [US1] Rename workflow eligibility, control-command parsing and guidance, managed branch defaults, PR label metadata, and fixtures while preserving checkpoint and authorization semantics in `elixir/lib/symphony_plus/github/`, `elixir/test/fixtures/`, and `.github/pull_request_template.md`
- [X] T013 [US1] Rename the repository workflow directory from `.symphony/` to `.symphony-plus/` and update its workflow, operator guide, startup paths, command vocabulary, branch contract, and issue label in `.symphony-plus/WORKFLOW.md` and `.symphony-plus/README.md`
- [X] T014 [US1] Rename repository-controlled profile, quota-wait, log, workspace-default, and other persisted path slugs without legacy migration or fallback, preserving boundary validation and atomic writes in `elixir/lib/symphony_plus/`, `elixir/config/`, and `elixir/test/support/`
- [X] T015 [US1] Run the focused US1 suites from T008-T014 and prove startup, reload, restart, dispatch, retry, reconciliation, cancellation, cleanup, review, and merge-queue behavior remains unchanged in `elixir/test/symphony_plus/`

**Checkpoint**: User Story 1 is independently operable using only canonical interfaces.

---

## Phase 4: User Story 2 - Read Consistent Product Documentation (Priority: P2)

**Goal**: Maintained product-facing text, specifications, examples, guides, and repository metadata consistently identify Symphony Plus while preserving explicit upstream references.

**Independent Test**: Review maintained prose and generated release metadata; all product references use Symphony Plus and every retained OpenAI Symphony reference is explicitly contextualized.

### Tests for User Story 2

- [X] T016 [P] [US2] Add documentation and release-metadata assertions for canonical product text and contextualized upstream references in `elixir/test/symphony_plus/documentation_contract_test.exs`

### Implementation for User Story 2

- [X] T017 [P] [US2] Rename the normative product contract and root-facing guides while preserving valid upstream URLs in `SPEC.md`, `README.md`, and `docs/`
- [X] T018 [P] [US2] Rename implementation and operator documentation, examples, templates, skill prose, logging guidance, commands, paths, and environment variables in `elixir/README.md`, `elixir/AGENTS.md`, `elixir/docs/`, `elixir/examples/`, `.codex/skills/`, and `.agents/skills/`
- [X] T019 [P] [US2] Rename controlled media and document filenames and all inbound references, retaining externally published URLs only when immutable and classified, in `.github/media/` and `docs/`
- [X] T020 [US2] Run the documentation contract test and manually classify every retained prose occurrence against FR-001, FR-009, and FR-011 in `elixir/test/symphony_plus/documentation_contract_test.exs` and `elixir/test/fixtures/product_identity_allowlist.txt`

**Checkpoint**: User Story 2 is independently reviewable with consistent branding and explicit exceptions.

---

## Phase 5: User Story 3 - Maintain a Coherent Renamed Codebase (Priority: P3)

**Goal**: Maintainers search, test, package, and extend one coherent Symphony Plus codebase without stale repository-controlled identifiers.

**Independent Test**: The source/test tree compiles, targeted suites pass, release outputs use canonical names, and the classified audit finds no unexplained legacy names or paths.

### Tests for User Story 3

- [X] T021 [P] [US3] Extend the product-identity audit coverage to configuration keys, log/UI text, fixtures, file paths, scripts, workflows, and application metadata in `elixir/test/symphony_plus/product_identity_test.exs`

### Implementation for User Story 3

- [X] T022 [US3] Rename remaining repository-controlled configuration keys, logger names, process metadata, dashboard titles, UI strings, fixtures, and source/test filenames in `elixir/config/`, `elixir/lib/symphony_plus/`, `elixir/lib/symphony_plus_web/`, and `elixir/test/`
- [X] T023 [US3] Rename Burrito targets, release commands, artifact/checksum names, smoke assertions, release titles, and installation variables in `.github/workflows/burrito-release.yml`, `elixir/rel/`, and `elixir/mix.exs`
- [X] T024 [US3] Execute the classified file-and-path audit and resolve or explicitly classify every remaining occurrence in `elixir/scripts/audit_product_identity.exs` and `elixir/test/fixtures/product_identity_allowlist.txt`

**Checkpoint**: All three stories use one canonical identity and every retained legacy occurrence has an allowed classification.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Validate the coordinated migration and perform the live metadata transition only at the safe handoff.

- [X] T025 Run all commands and expected outcomes in `specs/gh-18-rename-symphony-plus/quickstart.md`, including targeted rename/lifecycle tests and `make -C elixir all`
- [X] T026 Review the complete diff for secrets, generated output, unrelated refactors, unsupported aliases, broken upstream URLs, workspace-boundary regressions, and unexplained legacy occurrences across the repository
- [X] T027 At the workflow-safe final handoff, rename the live GitHub label `symphony` to `symphony-plus` in `rohanyupadhyay/symphony-plus` through the host-mediated GitHub API, preserving issue/PR association and recording the resulting metadata evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately; T002 and T003 can run together after the audit contract is understood.
- **Foundational (Phase 2)**: Depends on Phase 1 and blocks all stories because the application namespace must move atomically.
- **User Story 1 (Phase 3)**: Depends on Phase 2 and establishes operator contracts used by later documentation.
- **User Story 2 (Phase 4)**: Depends on the canonical US1 interfaces so documentation does not encode transient names.
- **User Story 3 (Phase 5)**: Depends on Phases 2-4 so its final audit evaluates the complete migration.
- **Polish (Phase 6)**: Depends on all stories; T027 is last and must occur only when the durable workflow can safely transition.

### User Story Dependencies

- **User Story 1 (P1)**: Starts after the atomic application rename; no dependency on US2 or US3.
- **User Story 2 (P2)**: Uses the canonical operator interfaces delivered by US1.
- **User Story 3 (P3)**: Audits and packages the complete identity established by US1 and documented by US2.

### Within Each User Story

- Add the focused failing assertions before changing the corresponding implementation.
- Rename coupled namespace/application identities atomically; do not leave forwarding aliases.
- Run targeted checks at each story checkpoint before proceeding.
- Delay the live label mutation until all repository contracts and validation evidence are ready.

### Parallel Opportunities

- T002 and T003 modify separate test files.
- T008, T009, and T010 cover separate operator boundaries.
- T017, T018, and T019 cover disjoint documentation/media groups.
- T016 can be authored while the US1 implementation is being validated, but it runs after canonical documentation is written.

---

## Parallel Example: User Story 1

```text
Task: "T008 Add failing CLI and launcher tests in elixir/test/symphony_plus/cli_test.exs and elixir/test/symphony_plus/scripts/run_github_test.exs"
Task: "T009 Add failing GitHub workflow tests in elixir/test/symphony_plus/github/"
Task: "T010 Add failing persisted-path and lifecycle tests in elixir/test/symphony_plus/ and elixir/test/support/"
```

## Implementation Strategy

### MVP First (User Story 1)

1. Build the classified audit and failing identity/release tests.
2. Complete the atomic internal application rename.
3. Complete and validate the operator-facing interface migration.
4. Stop and exercise the US1 independent test before documentation and release cleanup.

### Incremental Delivery

1. Establish canonical identities and test guardrails.
2. Deliver operator interfaces (US1).
3. Align maintained documentation and metadata (US2).
4. Complete internal/release cleanup and audit (US3).
5. Run full validation, inspect the diff, then perform the live label rename at the safe handoff.

## Notes

- `[P]` tasks operate on different files and have no incomplete dependency.
- Every retained legacy occurrence needs an explicit allowed classification; compatibility is not allowed.
- The custom checklist remains reviewer-owned and implementation must not change its markers.
- Commit coherent task groups and keep generated build/dependency output out of version control.
