# Symphony Plus Elixir

This directory contains the Elixir agent orchestration service that polls Linear, creates per-issue workspaces, and runs Codex in app-server mode.

## Environment

- Elixir: `1.19.x` (OTP 28) via `mise`.
- Install deps: `mix setup`.
- Main quality gate: `make all` (format check, lint, coverage, dialyzer).

## Install, validate, and run

Run development commands from the `elixir/` directory in the Symphony Plus source checkout:

```bash
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
make all
mise exec -- ./bin/symphony-plus --i-understand-that-this-will-be-running-without-the-usual-guardrails \
  --port 4000 --data-root "$HOME/.local/share/symphony-plus/development"
```

The final command starts an empty installation registry; register the actual target workflow
using the canonical guide. The canonical source-install and generic-run
details live in [`README.md`](README.md).

For GitHub issue orchestration, do not use the generic launcher or start Symphony Plus from an issue
workspace. Follow the [AI-agent installation runbook](docs/agent-installation.md), keep App
credentials in the host-side profile, and start the service from the source checkout with
`scripts/run-github`. Repository work then runs only in dedicated issue workspaces. This
repository's concrete operator command is documented in [`.symphony-plus/README.md`](../.symphony-plus/README.md).


## Codebase-Specific Conventions

- Runtime config is loaded from `WORKFLOW.md` front matter via `SymphonyPlus.Workflow` and `SymphonyPlus.Config`.
- Keep the implementation aligned with [`../SPEC.md`](../SPEC.md) where practical.
  - The implementation may be a superset of the spec.
  - The implementation must not conflict with the spec.
  - If implementation changes meaningfully alter the intended behavior, update the spec in the same
    change where practical so the spec stays current.
- Prefer adding config access through `SymphonyPlus.Config` instead of ad-hoc env reads.
- Workspace safety is critical:
  - Never run Codex turn cwd in source repo.
  - Workspaces must stay under configured workspace root.
- Orchestrator behavior is stateful and concurrency-sensitive; preserve retry, reconciliation, and cleanup semantics.
- Simplicity is a project constraint: prefer the smallest coherent design with one clear owner and
  invariant. Push back on extra abstractions, duplicated policy, and speculative flexibility.
- For stateful changes, check startup, reload, restart, and failure recovery together before editing.
- Follow `docs/logging.md` for logging conventions and required issue/session context fields.

## Tests and Validation

Run targeted tests while iterating, then run full gates before handoff.

- Prefer narrow tests that exercise real OTP processes and observable behavior over mock-only or
  broad end-to-end coverage; prove health with a synchronous call or stable effect, not only a PID.
- For non-trivial changes, use an adversarial review early to challenge complexity and try to break
  adjacent lifecycle paths; a reproducible failure blocks landing even if other reviews are clean.
- If tests need repeated global restarts or bespoke cleanup, first fix the shared harness or
  ownership boundary.

```bash
make all
```

## Required Rules

- Public functions (`def`) in `lib/` must have an adjacent `@spec`.
- `defp` specs are optional.
- `@impl` callback implementations are exempt from local `@spec` requirement.
- Evaluate proposed directions instead of agreeing reflexively; surface simpler designs and material
  trade-offs early.
- Keep changes narrowly scoped; avoid unrelated refactors.
- Follow existing module/style patterns in `lib/symphony_plus/*`.

Validation command:

```bash
mix specs.check
```

## PR Requirements

- PR body must follow `../.github/pull_request_template.md` exactly.
- Validate PR body locally when needed:

```bash
mix pr_body.check --file /path/to/pr_body.md
```

## Docs Update Policy

If behavior/config changes, update docs in the same PR:

- `../README.md` for project concept and goals.
- `README.md` for Elixir implementation and run instructions.
- `WORKFLOW.md` for workflow/config contract changes.

## Documentation correctness

Assess changed operator claims in every feature plan using the repository template's documentation
impact table. Update canonical instructions and generated facts in the same change; justified
no-impact results do not require unrelated README edits. Execute registered published commands with
`make docs-check`; use `mix docs.generate` only to deliberately update reference facts. Preserve
normative intent and track existing limitations in `docs/documentation-maintenance.md`.

Independent review reads actual changed code and docs from the current source head and reports
claims checked, observable evidence, unresolved findings, and external omissions under existing
PR/checkpoint headings. Fixes require review of the resulting head. Link actual CI results and
source/candidate SHAs; passing PR-body formatting does not prove evidence true. Analyze/converge
retain their installed scope: declared documentation work is feature intent, and converge appends
missing implementation tasks rather than becoming a Git diff auditor.
