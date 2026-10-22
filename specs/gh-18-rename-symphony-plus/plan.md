# Implementation Plan: Rename Symphony to Symphony Plus

**Branch**: `symphony/gh-18-rename-symphony-plus` | **Date**: 2026-10-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/gh-18-rename-symphony-plus/spec.md`

## Summary

Perform one coordinated, intentionally breaking rename of every repository-controlled product identity from Symphony/`symphony` to Symphony Plus and the interface-appropriate machine form. The implementation inventories and migrates operator contracts first, then the Elixir application/module tree and persisted names, then tests, fixtures, release automation, and documentation. A final classified audit permits only explicit upstream OpenAI Symphony or immutable external references.

## Technical Context

**Language/Version**: Elixir 1.19 on OTP 28; Bash and YAML for launch/release automation; Markdown for contracts and guides

**Primary Dependencies**: Existing Phoenix/LiveView service, Mix/escript, Burrito releases, ExUnit, GitHub Actions, repository-owned GitHub workflow control

**Storage**: Filesystem workspaces, log files, GitHub App profiles, durable quota-wait records, workflow checkpoints, and merge-queue state; no database migration

**Testing**: ExUnit targeted suites, Mix public-spec validation, formatting, Credo, coverage, Dialyzer, release/workflow assertions, repository-wide classified legacy-name audit, and `make -C elixir all`

**Target Platform**: Existing macOS and Linux targets and the repository's GitHub Actions workflows

**Project Type**: Elixir/OTP CLI and long-running orchestration service with an optional Phoenix observability surface

**Performance Goals**: No throughput or latency change; rename scans and test assertions complete within the existing quality-gate envelope

**Constraints**: Breaking rename with no legacy aliases; preserve orchestration and recovery semantics; retain accurate `openai/symphony` references; keep credentials host-side; make path renames collision-safe and reviewable

**Scale/Scope**: Repository-wide migration spanning root contracts/docs, `.symphony/`, Elixir source/tests/config/scripts, CI/release workflows, media and focused guide paths, and live GitHub label metadata

## Constitution Check

*GATE: Passed before Phase 0 research and re-checked after Phase 1 design.*

- **I. Specification and Contract Alignment — PASS**: `SPEC.md`, root/operator documentation, workflow examples, executable contracts, and release contracts are explicit implementation touchpoints. The plan changes naming only and preserves normative behavior.
- **II. Workspace and Credential Safety — PASS**: All work remains in the GH-18 issue workspace. Path/profile/default renames preserve boundary validation and host-side credential handling; the migration never copies secrets or reads credential payloads.
- **III. Lifecycle and Recovery Correctness — PASS**: Persisted quota, merge-queue, workflow-checkpoint, startup/reload/restart, dispatch, retry, cancellation, and cleanup paths receive regression coverage wherever renamed identifiers participate.
- **IV. Simplicity and Clear Ownership — PASS**: This is a direct repository-wide migration with one canonical mapping per interface and no compatibility layer or duplicate aliases.
- **V. Evidence-Driven Validation — PASS**: Targeted contract tests and rename scans precede implementation changes; the final gate is `make -C elixir all` plus release/workflow checks and the classified audit.
- **VI. Operational Observability — PASS**: Product titles, stable messages, log filenames, and relevant documentation are migrated without changing required issue/session context or exposing payloads.
- **Trust and sandbox posture — PASS**: Existing approval, sandbox, workspace, and host-tool boundaries remain unchanged and are covered as regression behavior.
- **Exceptions**: None.

**Post-design re-check**: The naming matrix, command contract, data/state inventory, and quickstart cover all constitution-mandated contracts and lifecycle surfaces. No violation or complexity exception was introduced.

## Project Structure

### Documentation (this feature)

```text
specs/gh-18-rename-symphony-plus/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── naming-contract.md
└── tasks.md                 # created by $speckit-tasks
```

### Source Code (repository root)

```text
README.md
SPEC.md
.github/
├── media/
└── workflows/
.symphony/                   # rename to .symphony-plus/
docs/
elixir/
├── AGENTS.md
├── README.md
├── WORKFLOW.md
├── config/
├── docs/
├── examples/
├── lib/
│   ├── symphony_elixir.ex   # rename with SymphonyPlus namespace tree
│   ├── symphony_elixir/
│   └── symphony_elixir_web/
├── scripts/
├── test/
│   ├── symphony_elixir/     # rename with application namespace
│   └── support/
├── Makefile
└── mix.exs
```

**Structure Decision**: Preserve the existing single Elixir application and repository layout. Rename directories/files only where their names encode the product identity; do not introduce adapters, migration layers, or a second application. Use `SymphonyPlus`/`SymphonyPlusWeb` for Elixir modules, `:symphony_plus` for the OTP application and release atom, `symphony-plus` for executable/path/label/command/artifact slugs, and `SYMPHONY_PLUS_*` for repository-controlled environment variables.

## Implementation Phases

### Phase A — Contract tests and canonical inventory

Add or update focused assertions for executable/release naming, `.symphony-plus/`, `/symphony-plus`, the `symphony-plus` label and branch prefix, profile/log/quota paths, UI text, and release assets. Establish a deterministic whole-word audit that classifies allowed upstream/immutable occurrences rather than applying an unsafe blind replacement.

### Phase B — Operator and workflow interfaces

Rename `.symphony/` and workflow-control vocabulary, parser/rendered guidance, label eligibility, launch scripts, GitHub App profile paths, branch conventions, and their fixtures. Preserve durable checkpoint state shape, merge-queue policy, host-mediated pushes, and current workflow semantics.

### Phase C — Elixir identity and persisted names

Rename the OTP application/release identity, escript output, module namespaces and source/test directories, configuration keys, logger handler/name, dashboard titles, log/quota/default workspace paths, and repository-controlled environment variables. Update all call sites atomically so there is no mixed runtime namespace.

### Phase D — Distribution, docs, and metadata

Rename Burrito artifacts/release titles, CI workflows and smoke fixtures, controlled media/guide paths, `SPEC.md`, root and Elixir READMEs, focused guides, examples, templates, and notices. Retain `openai/symphony` URLs only with clear upstream wording.

### Phase E — Live metadata and validation

After repository contracts are ready, rename the GitHub label through the API without losing issue association and only at the workflow-safe handoff. Run targeted tests, `make -C elixir all`, release/configuration checks, diff/secret review, and the classified repository-wide audit.

## Complexity Tracking

No constitution violations or justified complexity exceptions.
