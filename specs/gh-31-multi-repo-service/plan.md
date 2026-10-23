# Implementation Plan: Single Multi-Repository Service

**Branch**: `symphony-plus/gh-31-multi-repo-service` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

## Summary

Replace the singleton workflow/orchestrator with a service-level project registry that atomically
persists canonical workflow paths and dynamically supervises one isolated runtime per project. The
service starts empty, aggregates project-attributed status, and exposes identical add/list/remove
semantics through LiveView and CLI. Invalid restored workflows remain registered and retry safely.

## Technical Context

**Language/Version**: Elixir 1.19 on OTP 28

**Primary Dependencies**: OTP GenServer/DynamicSupervisor, Phoenix 1.8, LiveView 1.1, Jason, YamlElixir

**Storage**: Versioned atomic JSON at `elixir/tmp/symphony-plus/projects.json` by default (already ignored), with configurable local data root

**Testing**: ExUnit with real OTP processes and LiveView tests; targeted tests; `make -C elixir all`

**Target Platform**: Local Linux/macOS service and Burrito-packaged CLI

**Project Type**: Elixir OTP web service with CLI and LiveView

**Performance Goals**: Empty startup under 10 seconds; activation without restart; at least 10 projects

**Constraints**: One registry mutation owner; project-scoped config/tracker/workspaces; atomic writes; secret-safe output; idle-only removal
**Scale/Scope**: One trusted local operator, one service, at least 10 registered projects

## Constitution Check

*GATE: Passed before research and after Phase 1 design.*

- **I Contract Alignment — PASS**: preserves repository-owned workflows; implementation updates
  `SPEC.md`, root/Elixir READMEs, and focused operator guidance.
- **II Workspace/Credential Safety — PASS**: workflow bodies and credentials are never persisted;
  canonical workspace roots are validated and cross-project collisions rejected before activation.
- **III Lifecycle/Recovery — PASS**: `ProjectRegistry` is the sole mutation owner; operations are
  idempotent and atomic; startup, retry, reload, restart, partial failure, and removal are specified.
- **IV Simplicity/Ownership — PASS**: one registry and one DynamicSupervisor reuse project-scoped
  workflow/orchestrator logic; no database or distributed coordination is introduced.
- **V Evidence — PASS**: failing lifecycle, persistence, CLI, API, and LiveView tests precede code;
  targeted checks and the full gate are mandatory.
- **VI Observability — PASS**: stable events include non-secret `project_id`/workflow-path context;
  issue/session logs retain their required identifiers.

Post-design re-check: **PASS**. Contracts retain one owner, failure isolation, atomic recovery,
deterministic workspace boundaries, and consistent terminal/API/dashboard projections. No exception.

## Project Structure

### Documentation

```text
specs/gh-31-multi-repo-service/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/{cli.md,dashboard-api.md}
└── tasks.md
```

### Source Code

```text
SPEC.md
README.md
elixir/
├── README.md
├── docs/agent-installation.md
├── lib/symphony_plus.ex
├── lib/symphony_plus/{cli,project_registry,project_runtime,project_runtime_supervisor}.ex
├── lib/symphony_plus/{workflow_store,orchestrator,runtime_status,status_dashboard}.ex
├── lib/symphony_plus_web/live/dashboard_live.ex
├── lib/symphony_plus_web/controllers/observability_api_controller.ex
├── lib/symphony_plus_web/presenter.ex
└── test/symphony_plus/{cli,project_registry,project_runtime,extensions,orchestrator_status}_test.exs
```

**Structure Decision**: Extend the existing Elixir application. `ProjectRegistry` owns durable
configuration and lifecycle decisions; a DynamicSupervisor owns `ProjectRuntime` children; each
runtime owns project-specific workflow/config/orchestrator state. Presenters aggregate registry
snapshots instead of consulting a singleton orchestrator.

## Complexity Tracking

No constitution violations or exceptions.
