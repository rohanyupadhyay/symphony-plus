# Tasks: Safe Automatic Updates

**Input**: Design documents from `specs/gh-32-safe-auto-update/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required by Constitution Principle V. Each behavior task begins with a focused failing test and preserves red-green-refactor evidence.

**Organization**: Tasks are grouped by user story so safe adoption, unsafe-state refusal, and policy observability can be implemented and tested independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish update and external-helper test boundaries without changing runtime behavior.

- [ ] T001 Create supervised update module boundaries with adjacent public `@spec` declarations in `elixir/lib/symphony_plus/update_manager.ex` and `elixir/lib/symphony_plus/source_update.ex`
- [ ] T002 [P] Create temporary-repository and command-boundary test support in `elixir/test/support/source_update_case.ex`
- [ ] T003 [P] Create external activation-helper test harness in `elixir/test/support/source_update_helper.ex`

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add validated configuration and supervision required by every story.

- [ ] T004 Write failing schema tests for omitted/disabled updates and these exact constraints—`interval_ms` positive; `installation_root` absolute, a validated checkout, and outside `workspace.root`; `remote` an existing simple name defaulting to `origin`; commands required when enabled and rejecting literal credentials—in `elixir/test/symphony_plus/config_schema_test.exs`
- [ ] T005 Implement the `updates` schema and typed accessors through `SymphonyPlus.Config`, preserving last-known-good settings on invalid reload, in `elixir/lib/symphony_plus/config/schema.ex` and `elixir/lib/symphony_plus/config.ex`
- [ ] T006 Write a failing supervision test proving the manager is inert while disabled and restarts cleanly in `elixir/test/symphony_plus/update_manager_test.exs`
- [ ] T007 Supervise `SymphonyPlus.UpdateManager` without update-source activity in disabled mode in `elixir/lib/symphony_plus.ex` and `elixir/lib/symphony_plus/update_manager.ex`

**Checkpoint**: Configuration and lifecycle ownership exist while default behavior remains unchanged.

## Phase 3: User Story 1 - Adopt an Available Update Safely (Priority: P1) 🎯 MVP

**Goal**: Detect, prepare, drain for, and activate one immutable default-branch revision without interrupting admitted work.

**Independent Test**: Advance a temporary remote while admitted work and an automatic continuation are present; verify exact-SHA preparation, blocked unrelated dispatch, uninterrupted admitted work, atomic quiescence, and restart on that SHA.

### Tests for User Story 1

- [ ] T008 [P] [US1] Write failing repository tests for remote default-branch discovery, full 40-character SHA identity, deduplication, detached candidate preparation, and remote movement invalidation in `elixir/test/symphony_plus/source_update_test.exs`
- [ ] T009 [P] [US1] Write failing real-orchestrator tests for idempotent drain/cancel, fresh-dispatch blocking, allowed claimed continuations, and atomic quiescence across running, retry, quota, workflow continuation, and automatic-review state in `elixir/test/symphony_plus/orchestrator_test.exs`
- [ ] T010 [P] [US1] Write failing merge-queue tests for repository/target queue-idle admission and activity deferral in `elixir/test/symphony_plus/github_merge_queue_test.exs`
- [ ] T011 [US1] Write failing manager tests for non-overlapping intervals, one pending generation, prepare-before-drain, immediate pre-activation recheck, and exactly one handoff in `elixir/test/symphony_plus/update_manager_test.exs`
- [ ] T012 [US1] Write failing helper integration tests for lock acquisition, old-PID exit, old/candidate SHA verification, fast-forward-only installation, prepared-build use, and launcher handoff in `elixir/test/symphony_plus/source_update_script_test.exs`

### Implementation for User Story 1

- [ ] T013 [US1] Implement validated remote/default-branch resolution, immutable candidate discovery, detached worktree preparation, and preparation command execution in `elixir/lib/symphony_plus/source_update.ex`
- [ ] T014 [US1] Add orchestrator-owned drain generation, cancellation, dispatch gating, and atomic quiescence APIs without sharing mutable runtime maps in `elixir/lib/symphony_plus/orchestrator.ex`
- [ ] T015 [US1] Add a synchronous repository/target activity query for update admission in `elixir/lib/symphony_plus/github/merge_queue.ex` and `elixir/lib/symphony_plus/github/merge_queue/state.ex`
- [ ] T016 [US1] Implement manager scheduling and state transitions using exact candidate rules—`revision` is a 40-character SHA, `default_branch` is captured at detection, `detected_at` is UTC, `prepared_path` stays outside issue workspaces, `preparation_state` is `unprepared|preparing|ready|failed`, and `attempted` prevents repeated activation—in `elixir/lib/symphony_plus/update_manager.ex`
- [ ] T017 [US1] Implement admission using exact fields—ready `candidate_revision`, `prior_revision`, current `drain_token`, `admitted_at` after atomic quiescence and idle queue replies, and `activation_state` in `waiting|admitted|handoff_started|restarted|blocked`—in `elixir/lib/symphony_plus/update_manager.ex`
- [ ] T018 [US1] Implement locked fast-forward-only activation, preserved prior executable, sanitized arguments, old-process handoff, and launcher restart in `elixir/scripts/apply-source-update`
- [ ] T019 [US1] Run the User Story 1 focused suite and record red-green-refactor evidence in `specs/gh-32-safe-auto-update/quickstart.md`

**Checkpoint**: A clean source checkout can safely adopt one prepared immutable revision after admitted work drains.

## Phase 4: User Story 2 - Refuse Unsafe Updates (Priority: P2)

**Goal**: Preserve the running installation and operator work when repository state, ownership, preparation, or activation is unsafe.

**Independent Test**: Exercise dirty, untracked, detached, divergent, wrong-remote, moved-branch, lock-contention, preparation-failure, and activation-failure scenarios and verify no destructive mutation, no issue-workspace mutation, and a bounded recovery outcome.

### Tests for User Story 2

- [ ] T020 [P] [US2] Write failing repository-safety tests for tracked/untracked dirt, detached/divergent HEAD, wrong repository/remote, moved candidate, installation/workspace boundary violations, and lock contention in `elixir/test/symphony_plus/source_update_test.exs`
- [ ] T021 [P] [US2] Write failing helper recovery tests covering failure before process exit, after exit, during fast-forward/install, launcher failure, prior-executable recovery, and stale-lock handling in `elixir/test/symphony_plus/source_update_script_test.exs`
- [ ] T022 [US2] Write failing manager restart-recovery tests proving authoritative checkout-HEAD discovery and preservation/reconciliation of issue workspaces, workflow checkpoints, quota-wait records, and merge-queue records, plus source-unavailable retry without drain, bounded preparation failure, blocked activation, no repeated activation, and disable-during-pending behavior in `elixir/test/symphony_plus/update_manager_test.exs`

### Implementation for User Story 2

- [ ] T023 [US2] Enforce canonical installation identity, clean attached fast-forward eligibility, issue-workspace exclusion, lock ownership, moved-revision invalidation, and non-destructive command allowlists in `elixir/lib/symphony_plus/source_update.ex`
- [ ] T024 [US2] Add deterministic failure classification, bounded non-secret recovery cues, later-interval retry for source failures, and drain release for safely abandoned candidates in `elixir/lib/symphony_plus/update_manager.ex`
- [ ] T025 [US2] Add trap-based prior-executable recovery and bounded blocked-outcome recording without reset, rebase, history deletion, or restart loops in `elixir/scripts/apply-source-update`
- [ ] T026 [US2] Add startup reconciliation for authoritative checkout HEAD, owned temporary worktrees, stale locks, and existing durable workflow stores in `elixir/lib/symphony_plus/update_manager.ex`
- [ ] T027 [US2] Run the User Story 2 focused suite and record failure/recovery evidence in `specs/gh-32-safe-auto-update/quickstart.md`

**Checkpoint**: Unsafe and partial-failure paths leave operator work and the last runnable installation recoverable.

## Phase 5: User Story 3 - Operate and Observe Update Policy (Priority: P3)

**Goal**: Let operators configure, reload, and diagnose the update lifecycle through one consistent bounded status projection.

**Independent Test**: Compare disabled and enabled instances across reload and all status states; verify zero disabled-mode activity and identical terminal, JSON, LiveView, and structured-log evidence.

### Tests for User Story 3

- [ ] T028 [P] [US3] Write failing reload tests for cadence reschedule, non-overlap, immediate disable/cancel, validated source/activation replacement, and last-known-good retention in `elixir/test/symphony_plus/workflow_store_test.exs` and `elixir/test/symphony_plus/update_manager_test.exs`
- [ ] T029 [P] [US3] Write failing presenter and dashboard tests for one update snapshot with states `disabled|current|checking|preparing|pending|draining|activating|blocked|failed`, full-SHA-or-null revisions, UTC-or-null `last_checked_at`, bounded `last_outcome`, and single-line non-secret `reason` in `elixir/test/symphony_plus/runtime_status_test.exs`, `elixir/test/symphony_plus/status_dashboard_snapshot_test.exs`, and `elixir/test/symphony_plus_web/presenter_test.exs`
- [ ] T030 [P] [US3] Write failing capture-log tests for stable `update check`, `update candidate`, `update drain`, and `update activation` wording with bounded installation/revision context and no credentials, raw payloads, environment values, or unrelated private paths in `elixir/test/symphony_plus/update_manager_test.exs`

### Implementation for User Story 3

- [ ] T031 [US3] Wire validated dynamic update settings and disable/cancel behavior from workflow reloads to the manager in `elixir/lib/symphony_plus/workflow_store.ex` and `elixir/lib/symphony_plus/update_manager.ex`
- [ ] T032 [US3] Expose one manager status snapshot through runtime status, terminal dashboard, JSON, and LiveView presentation in `elixir/lib/symphony_plus/runtime_status.ex`, `elixir/lib/symphony_plus/status_dashboard.ex`, and `elixir/lib/symphony_plus_web/presenter.ex`
- [ ] T033 [US3] Emit stable concise lifecycle logs with sanitized installation and revision context in `elixir/lib/symphony_plus/update_manager.ex` and `elixir/lib/symphony_plus/source_update.ex`
- [ ] T034 [US3] Run the User Story 3 focused suite and record reload/status/log evidence in `specs/gh-32-safe-auto-update/quickstart.md`

**Checkpoint**: Operators can configure and diagnose every update state without exposing secrets or divergent status.

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T035 [P] Update automatic-update normative behavior and configuration in `SPEC.md` and `elixir/WORKFLOW.md`
- [ ] T036 [P] Document eligibility, safe-idle semantics, source-checkout prerequisites, update/restart ownership, configuration, recovery, the numeric preparation/restart allowance and its measurement boundary, and external supervisor responsibilities in `README.md`, `elixir/README.md`, `.symphony-plus/README.md`, and `elixir/docs/agent-installation.md`
- [ ] T037 [P] Document stable update lifecycle messages and context/redaction rules in `elixir/docs/logging.md`
- [ ] T038 Run all quickstart scenarios and targeted update/orchestrator/merge-queue/presenter tests from `specs/gh-32-safe-auto-update/quickstart.md`
- [ ] T039 Run `make -C elixir all`, inspect the diff for secrets, generated artifacts, unrelated changes, incomplete tasks, and constitution violations, and record omissions in `specs/gh-32-safe-auto-update/quickstart.md`

## Dependencies & Execution Order

- Setup starts immediately; Foundational depends on Setup and blocks all stories.
- User Story 1 depends on Foundational and delivers the MVP.
- User Story 2 depends on User Story 1 activation boundaries.
- User Story 3 depends on manager states established by User Stories 1 and 2.
- Polish depends on all three stories.
- Within each story, tests must fail before implementation; repository/orchestration boundaries precede manager consumers; targeted validation completes the story.

## Parallel Opportunities

- T002 and T003; T008/T009/T010; T020/T021; T028/T029/T030; and T035/T036/T037 are parallel groups.

## Parallel Example: User Story 1

```text
T008: repository discovery/preparation tests in source_update_test.exs
T009: drain/quiescence tests in orchestrator_test.exs
T010: queue-idle tests in github_merge_queue_test.exs
```

## Implementation Strategy

1. Complete Setup and Foundational.
2. Complete User Story 1 through T019 and validate the MVP.
3. Add refusal/recovery through User Story 2.
4. Add reload and unified operator evidence through User Story 3.
5. Synchronize normative/operational docs and run full gates.

## Notes

- Custom checklist markers remain reviewer-owned and are not implementation task state.
- Mark each task `[X]` only after its work and targeted validation complete.
- Preserve one authoritative manager for update state and the orchestrator as sole owner of issue lifecycle state.
- Never reset, rebase, destructively clean, mutate issue workspaces, or handle raw credentials.
