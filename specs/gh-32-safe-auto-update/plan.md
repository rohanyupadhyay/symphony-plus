# Implementation Plan: Safe Automatic Updates

**Branch**: `symphony-plus/gh-32-safe-auto-update` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

## Summary

Add an opt-in `updates` workflow configuration and supervised `UpdateManager`. It resolves the configured GitHub default branch to an immutable commit, prepares and validates that commit in a detached temporary worktree, and asks the orchestrator to drain unrelated dispatch. Once all admitted work, automatic continuations, and merge-queue activity are quiescent, an installation-locked external helper revalidates the checkout, fast-forwards to the admitted commit, installs the prepared build, and hands restart to the documented launcher/supervisor. The manager owns update state; the orchestrator remains the sole owner of issue lifecycle and dispatch state.

## Technical Context

**Language/Version**: Elixir 1.19 / OTP 28; POSIX shell for activation

**Primary Dependencies**: OTP, existing `Config`, `WorkflowStore`, `Orchestrator`, `GitHub.MergeQueue`, `StatusDashboard`, system Git and Mise

**Storage**: In-memory update state, filesystem installation lock, detached Git worktree; existing durable work stores unchanged

**Testing**: ExUnit with supervised processes and temporary Git repositories; `mix specs.check`; `make -C elixir all`

**Target Platform**: Linux/macOS source checkout with Git, Bash, Mise, and an external launcher/supervisor

**Project Type**: Long-running OTP service with CLI launcher and optional Phoenix status UI/API

**Performance Goals**: Disabled mode makes zero requests; checks never overlap; no-update checks do not delay issue polling

**Constraints**: Opt-in; immutable SHA; no issue-workspace mutation; no reset/rebase/destructive cleanup; no credential exposure; no interruption of admitted work; runnable prior executable retained

**Scale/Scope**: One local installation, guarded against a second updater; one pending candidate; GitHub default branch only

## Constitution Check

*GATE: Passed before research and after design.*

| Principle | Evidence | Result |
|---|---|---|
| I. Contract alignment | `SPEC.md`, root/Elixir READMEs, workflow contract, and operator runbook are implementation deliverables. | PASS |
| II. Workspace/credential safety | Validate repository boundaries; prepare outside issue workspaces; retain host auth; expose only bounded non-secret diagnostics. | PASS |
| III. Lifecycle/recovery | One update owner; orchestrator-owned drain; test startup, reload, restart, retries, quota/review/queue drain, failures, and recovery. | PASS |
| IV. Simplicity/ownership | One manager, narrow drain API, pure repository boundary, and external helper; no generic deployment framework. | PASS |
| V. Evidence-driven validation | Focused failing tests first, public specs, targeted checks, then the full gate. | PASS |
| VI. Observability | One update snapshot feeds terminal, JSON, LiveView, and stable structured logs; docs change together. | PASS |

No exception or complexity waiver is required.

## Project Structure

```text
specs/gh-32-safe-auto-update/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/{update-config.md,update-status.md}
└── tasks.md

SPEC.md
README.md
.symphony-plus/README.md
elixir/
├── README.md
├── WORKFLOW.md
├── docs/{agent-installation.md,logging.md}
├── scripts/{run-github,apply-source-update}
├── lib/symphony_plus.ex
├── lib/symphony_plus/{config.ex,orchestrator.ex,source_update.ex,update_manager.ex}
├── lib/symphony_plus/config/schema.ex
├── lib/symphony_plus/github/merge_queue.ex
├── lib/symphony_plus_web/presenter.ex
└── test/{symphony_plus,symphony_plus_web}/
```

**Structure Decision**: `UpdateManager` owns checks, candidates, locking, admission, and status. `SourceUpdate` owns pure and command-boundary repository operations. The orchestrator exposes idempotent drain/cancel and atomic quiescence calls without sharing mutable maps. `apply-source-update` is external because final checkout mutation and restart must survive the BEAM exiting.

## Phase 0: Research Outcomes

See [research.md](research.md). All unknowns are resolved: use the existing remote and advertised default branch; identify candidates by full SHA; prepare in a detached worktree; block only fresh unrelated dispatch; include merge-queue activity in safe idle; activate through a locked external helper; retain last-known-good dynamic settings.

## Phase 1: Design and Contracts

See [data-model.md](data-model.md), [update-config.md](contracts/update-config.md), [update-status.md](contracts/update-status.md), and [quickstart.md](quickstart.md).

### Runtime flow

1. The manager reloads validated settings, stays inert while disabled, and schedules one non-overlapping check.
2. The source boundary validates installation, clean attached branch, remote, and lock, fetches the default branch, and returns its full SHA.
3. A new SHA is prepared in a detached worktree and passes setup, build, updater tests, and the full gate before becoming ready.
4. The manager requests drain. The orchestrator blocks only fresh unrelated dispatch; claimed work and continuations retain existing behavior.
5. Activation is admitted after atomic orchestrator quiescence and idle merge-queue replies, immediately rechecked with repository identity under the lock.
6. The manager starts the helper with sanitized arguments. It waits for the old PID to exit, fast-forwards to the exact SHA, installs the prepared build, and restarts through the launcher/supervisor contract.
7. On activation failure, the helper runs the preserved prior executable and records a bounded blocked reason. It never resets, rebases, deletes history, or mutates issue workspaces.

### Test strategy

- Schema tests: disabled default, positive interval, safe roots, reload, secret-free serialization.
- Temporary Git tests: current, fast-forward, dirty/untracked, detached, divergent, moved branch, wrong remote, lock contention, preparation failure, exact-SHA activation.
- Real orchestrator tests: drain blocks fresh dispatch and waits for running, retry, quota, review, and continuation state.
- Manager tests: non-overlap, deduplication, retry/reporting, disable/cancel, double-check, single activation.
- Restart tests: durable workspace/checkpoint/quota/merge-queue evidence and prior-executable recovery.
- Presenter/log tests: identical bounded status across all surfaces.

## Complexity Tracking

No violations to justify.
