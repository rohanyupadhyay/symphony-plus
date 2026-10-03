<!--
Sync Impact Report
- Version change: 1.0.0 -> 1.1.0
- Modified principles/sections: Development Workflow and Quality Gates (agent merge authority)
- Added sections: None
- Removed sections: None
- Follow-up TODOs: None
-->

# Symphony Plus Constitution

## Core Principles

### I. Specification and Contract Alignment

Every change MUST remain compatible with the normative behavior in `SPEC.md`. When behavior,
configuration, or an externally visible contract changes, the same change MUST update `SPEC.md`
and the applicable operator or implementation documentation. An implementation MAY extend the
specification, but it MUST NOT contradict it. Reviewers MUST reject feature artifacts or code that
silently redefine the root specification.

### II. Workspace and Credential Safety

Coding agents MUST run only inside deterministic, per-issue workspaces under the configured
workspace root; they MUST NOT run in the Symphony source checkout or another issue's workspace.
Tracker credentials and private keys MUST remain host-side, MUST NOT enter agent environments,
logs, prompts, commits, issues, or pull requests, and MUST be exposed only through approved
host-mediated tools. Workspace paths, lifecycle hooks, pushes, and cleanup MUST validate their
targets and preserve repository boundaries before mutation.

### III. Lifecycle and Recovery Correctness

Every stateful change MUST define and test its effects on startup, dynamic reload, restart,
dispatch, retry, reconciliation, cancellation, terminal cleanup, and partial failure wherever
those paths are applicable. The orchestrator MUST retain one authoritative owner for mutable
runtime state and MUST keep transitions idempotent across repeated polls or recovered sessions.
A reproducible failure in an adjacent lifecycle path blocks release even when the primary path
passes.

### IV. Simplicity and Clear Ownership

Changes MUST use the smallest coherent design with one clear owner and invariant. Configuration
access MUST flow through `SymphonyElixir.Config`; workflow policy MUST remain in repository-owned
workflow prompts; tracker-specific behavior MUST remain behind adapter and host-tool boundaries.
Speculative flexibility, duplicated policy, unrelated refactors, and abstractions without a current
consumer MUST be rejected or justified explicitly in the feature plan.

### V. Evidence-Driven Validation

Behavior changes MUST begin with a reproducible signal and a focused failing test, then follow a
red-green-refactor cycle against observable behavior. Tests SHOULD exercise real OTP processes and
synchronous effects rather than only mocks or PID existence. Public `def` functions in `lib/` MUST
have an adjacent `@spec`, except `@impl` callbacks; private function specs remain optional. Every
handoff MUST pass targeted checks and then `make -C elixir all`, including formatting, public-spec
validation, Credo, coverage, and Dialyzer.

### VI. Operational Observability

Lifecycle events MUST use stable, concise wording and include the context required by
`elixir/docs/logging.md`: issue identifiers for issue work and session identifiers for Codex
execution. Failures MUST record their outcome and reason without dumping secrets or unnecessary
payloads. Changes that affect configuration, operation, logging, or user-visible behavior MUST
update the relevant root README, Elixir README, workflow contract, or focused guide in the same
pull request.

## Authority and Engineering Constraints

Authority descends in this order:

1. `SPEC.md` defines normative Symphony product behavior and cannot be relaxed by this document.
2. This constitution governs how changes are specified, planned, implemented, validated, and
   reviewed.
3. `elixir/AGENTS.md`, `elixir/docs/logging.md`, `elixir/Makefile`, and
   `.github/pull_request_template.md` define established implementation and handoff rules.
4. Current code and tests are evidence of existing behavior, not authority to contradict a higher
   source.

The supported implementation uses Elixir 1.19 on OTP 28 through `mise`. Changes MUST follow
existing `lib/symphony_elixir/*` module and style patterns. Trust and sandbox choices MUST be
documented explicitly because the service operates coding agents with repository access.

## Development Workflow and Quality Gates

Every feature MUST progress through specification, clarification, planning, checklist, task,
analysis, implementation, and convergence before review. Planning and analysis MUST include an
explicit Constitution Check; unresolved violations block implementation. Critical or high
analysis findings MUST be remediated in the owning artifact before implementation approval.

Implementation MUST remain narrowly scoped, preserve the pull request template exactly, and record
targeted plus full-gate validation. Non-trivial changes MUST receive an adversarial review that
challenges complexity and adjacent lifecycle paths. Human review and approval are mandatory.
Symphony Plus MAY merge a pull request only after required reviews and status checks pass, no
blocking review feedback remains, and the pull request satisfies the repository's merge policy.
Exceptions to a principle require an explicit complexity entry in the plan, the rejected simpler
alternative, and reviewer approval.

## Governance

This constitution governs all Spec Kit artifacts and implementation reviews, but it cannot override
the normative product contract in `SPEC.md`. Each specification, plan, analysis, and pull request
review MUST verify compliance and cite any approved exception. Reviewers MUST stop changes whose
artifacts, implementation, validation evidence, or documentation disagree.

Amendments require a dedicated reviewed pull request that explains the reason, affected workflows,
and any migration steps. Versions follow semantic versioning: MAJOR removes or incompatibly
redefines governance, MINOR adds a principle or materially expands obligations, and PATCH clarifies
wording without changing obligations. The amendment MUST update the version and ISO date; the
ratification date remains the date of initial adoption.

**Version**: 1.1.0 | **Ratified**: 2026-09-28 | **Last Amended**: 2026-10-03
