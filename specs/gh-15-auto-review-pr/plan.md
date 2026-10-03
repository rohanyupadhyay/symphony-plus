# Implementation Plan: Automatically Review Symphony Pull Requests

**Branch**: `symphony/gh-15-auto-review-pr` | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/gh-15-auto-review-pr/spec.md`

## Summary

Extend GitHub workflow control with a durable, immediately dispatchable `review_pending` checkpoint. The originating issue remains the sole scheduler and workspace identity: after Symphony creates and labels its pull request, it records the pull request number and pushed branch/head in the checkpoint; the next successful poll resumes the same issue workspace for an automatic review-and-repair pass. Completion replaces that checkpoint with the existing `awaiting_review` handoff. GitHub-visible checkpoint state makes the transition restart-safe, while durable dispatch consumption prevents duplicate automatic dispatch.

## Technical Context

**Language/Version**: Elixir 1.19 on OTP 28

**Primary Dependencies**: OTP/GenServer, Req-based GitHub client, Jason, existing Symphony tracker and Codex app-server abstractions

**Storage**: GitHub issue comments and pull request labels/check/review state; no Symphony database

**Testing**: ExUnit focused GitHub adapter/workflow-control/agent-tool/orchestrator tests; `make -C elixir all`

**Target Platform**: Long-running Linux/macOS Symphony service using GitHub Issues and GitHub App or PAT authentication

**Project Type**: Elixir/OTP service and CLI

**Performance Goals**: Eligible pull requests become dispatchable on the next successful configured poll without adding GitHub API calls for unrelated issues

**Constraints**: One authoritative issue worker and workspace; polling rather than webhooks; idempotent recovery from GitHub-visible state; credentials remain host-side; same-repository, non-fork pull requests only; human approval remains mandatory

**Scale/Scope**: One managed pull request per eligible originating issue, bounded by existing issue-level concurrency and polling limits

## Constitution Check

*GATE: Passed before Phase 0 and re-checked after Phase 1 design.*

- **I. Specification and Contract Alignment — PASS**: The design extends the root product contract with managed-PR continuation and updates GitHub operator documentation and workflow policy in the same change.
- **II. Workspace and Credential Safety — PASS**: Review work reuses the deterministic originating-issue workspace. GitHub mutations continue through host-mediated tools; no credential flow changes.
- **III. Lifecycle and Recovery Correctness — PASS**: The state contract covers creation, partial label/checkpoint failure, repeated polls, restart, cancellation, close/merge, retry, later feedback, and terminal cleanup. Durable dispatch consumption prevents concurrent duplicate work.
- **IV. Simplicity and Clear Ownership — PASS**: The existing issue workflow remains the only owner. One additional checkpoint state is smaller than a second pull-request scheduler identity or webhook subsystem.
- **V. Evidence-Driven Validation — PASS**: Tasks must begin with focused failing tests for transition, recovery, and duplicate suppression, then run targeted tests and `make -C elixir all`.
- **VI. Operational Observability — PASS**: Stable transition/failure logs carry issue and pull-request context, and operator documentation describes recovery and handoff.
- **Post-design re-check — PASS**: The data model and contract retain the same ownership, storage, safety, testing, and documentation boundaries. No exception is required.

## Architecture and Lifecycle

1. The implementation phase creates or updates the one managed pull request, applies the `symphony` label idempotently, and records a `review_pending` checkpoint on the originating issue only after the branch head is pushed.
2. `WorkflowControl` validates and derives `review_pending`. A newly recorded checkpoint with no consumed dispatch cursor is dispatchable without a human comment.
3. The GitHub adapter enriches the originating issue with the managed pull request, conversations, reviews, inline comments, check runs/statuses, and merge state needed by the automatic pass.
4. The orchestrator applies its existing issue-level claim/running rules, so only the originating issue's worker can mutate the branch.
5. The review turn inspects the complete supplied context, uses GitHub APIs for additional evidence, repairs in scope, validates, pushes the same branch, updates the same pull request, and posts a normal `awaiting_review` checkpoint.
6. Repeated polling and restart reconstruction see the consumed durable review dispatch and do not start the initial automatic review again. Later authorized review/check events resume through existing review cursor semantics.
7. Label removal, issue closure, or pull request closure/merge prevents new automatic work; active work is stopped or reconciled through existing issue routing and the new PR terminal-state checks.

## Project Structure

### Documentation (this feature)

```text
specs/gh-15-auto-review-pr/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── managed-pr-review.md
└── tasks.md                 # generated after plan approval
```

### Source Code (repository root)

```text
SPEC.md
README.md
elixir/
├── README.md
├── docs/github-workflow-control.md
├── examples/github-speckit-WORKFLOW.md
├── lib/symphony_elixir/github/
│   ├── agent_tool.ex
│   ├── client.ex
│   └── workflow_control.ex
└── test/symphony_elixir/
    ├── github_adapter_test.exs
    ├── github_launcher_test.exs
    └── github_workflow_control_test.exs
```

**Structure Decision**: Extend the existing GitHub workflow-control boundary. `WorkflowControl` owns durable state and trigger derivation, `Client` owns GitHub enrichment, and `AgentTool` owns validated checkpoint writes. The generic orchestrator needs no pull-request-specific scheduler or second workspace identity. Repository workflow text owns the review procedure, while product and operator documents define the external behavior.

## Phase 0: Research

Research resolves durable dispatch semantics, single-owner scheduling, GitHub check retrieval, and partial-failure ordering. Decisions and rejected alternatives are recorded in [research.md](research.md).

## Phase 1: Design and Contracts

- [data-model.md](data-model.md) defines managed pull request and review-cycle state, identities, validation rules, and transitions.
- [contracts/managed-pr-review.md](contracts/managed-pr-review.md) defines checkpoint, enrichment, trigger, and handoff behavior.
- [quickstart.md](quickstart.md) defines end-to-end validation for happy-path, retry/restart, failure, cancellation, and human handoff scenarios.

## Complexity Tracking

No constitution violations or justified complexity exceptions.
