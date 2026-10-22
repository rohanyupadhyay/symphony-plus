# Implementation Plan: Install and Run Documentation

**Branch**: `symphony-plus/gh-13-install-run-docs` | **Date**: 2026-10-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/gh-13-install-run-docs/spec.md`

## Summary

Add an immediately copyable source-install and generic-run sequence to the root README, retain
`elixir/README.md` as the detailed canonical command reference, and make likely human, agent, and
operator surfaces point to the correct generic or GitHub App-authenticated launch path. This is a
documentation-only change: audit existing commands and links, update the smallest set of Markdown
files needed for discoverability and consistency, and validate references without changing runtime
behavior or `SPEC.md`.

## Technical Context

**Language/Version**: Markdown for an Elixir 1.19 / OTP 28 application managed by `mise`

**Primary Dependencies**: `mise`, Mix, generated `elixir/bin/symphony-plus`, and `elixir/scripts/run-github`

**Storage**: N/A; repository-tracked Markdown only

**Testing**: command/path inspection, repository-relative link audit, `git diff --check`, targeted documentation assertions, and `make -C elixir all`

**Target Platform**: supported source-development hosts with Git, Bash-compatible examples, `mise`, and Codex; released binaries remain an alternative

**Project Type**: documentation change for a CLI/service repository

**Performance Goals**: N/A; no runtime change

**Constraints**: commands must be copyable in order; working directories and workflow paths must be explicit; generic and GitHub modes must remain distinct; credentials stay host-side; issue agents never operate from the source checkout

**Scale/Scope**: `README.md`, `elixir/README.md`, `elixir/AGENTS.md`, `.symphony-plus/README.md`, and `elixir/docs/agent-installation.md`

## Constitution Check

*GATE: Passed before Phase 0 research and re-checked after Phase 1 design.*

- **I. Specification and Contract Alignment — PASS**: Discoverability changes preserve `SPEC.md` behavior and boundaries; the normative contract remains unchanged.
- **II. Workspace and Credential Safety — PASS**: Generic startup remains in the source checkout; GitHub orchestration remains App-authenticated and sends issue work to dedicated workspaces. No secret values or credential-copying instructions are introduced.
- **III. Lifecycle and Recovery Correctness — PASS / not applicable**: No stateful runtime change is planned. Existing startup and recovery behavior is referenced, not modified.
- **IV. Simplicity and Clear Ownership — PASS**: `elixir/README.md` remains the canonical detailed install/run owner; other surfaces provide a concise quick start or direct links instead of competing procedures.
- **V. Evidence-Driven Validation — PASS**: Paths and commands will be checked against repository files, followed by targeted documentation checks and `make -C elixir all`.
- **VI. Operational Observability — PASS**: The quick start will state the observable startup outcome and link to focused GitHub and self-hosting guides.
- **Workflow gates — PASS**: Scope is narrow, all planning artifacts are produced, and no exception needs Complexity Tracking.

**Post-design re-check**: Research, the documentation contract, data model, and validation
quickstart preserve every gate above. No constitution exception or `SPEC.md` change is required.

## Project Structure

### Documentation (this feature)

```text
specs/gh-13-install-run-docs/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── documentation-surfaces.md
└── tasks.md                         # created by $speckit-tasks after plan approval
```

### Repository files in implementation scope

```text
README.md                            # human-facing source quick start and routing
elixir/README.md                     # canonical source install and generic run commands
elixir/AGENTS.md                     # agent-facing command summary and links
.symphony-plus/README.md                  # repository-specific GitHub self-hosting guide
elixir/docs/agent-installation.md    # canonical agent-operated GitHub onboarding
SPEC.md                              # read-only normative compatibility reference
```

**Structure Decision**: Keep documentation with its existing audience-specific owner. Add no
runtime modules, scripts, or configuration. The root README owns discovery, the Elixir README owns
generic source installation and execution, the agent guide owns development commands, and the two
focused guides own GitHub App onboarding and self-hosting.

## Implementation Phases

### Phase 1 — Establish the canonical command sequence

Audit `elixir/README.md`, `elixir/Makefile`, Mix aliases, launcher generation, and workflow
examples. Resolve drift in detailed source-install/generic-run instructions before referencing
them elsewhere. Label prerequisites, starting directory, explicit workflow path, and startup result.

### Phase 2 — Improve human and agent discovery

Add the concise quick start and generic launch command to `README.md`. Update `elixir/AGENTS.md`
with an agent-safe command summary and direct links to detailed generic and GitHub onboarding
guides. Keep duplicated text short and consistent with the canonical sequence.

### Phase 3 — Reconcile focused GitHub guidance

Audit `.symphony-plus/README.md` and `elixir/docs/agent-installation.md` for command consistency,
source-checkout versus issue-workspace boundaries, App-authenticated launcher use, and cross-links.
Change only omissions or conflicts; preserve repository-specific self-hosting values.

### Phase 4 — Validate the documentation set

Check every changed repository-relative link and executable path, compare repeated commands,
search for unresolved placeholders, run `git diff --check`, and run `make -C elixir all`. Review
the final diff for secrets, unrelated changes, generated artifacts, and accidental runtime or
`SPEC.md` modifications.

## Complexity Tracking

No constitution violations or complexity exceptions are required.
