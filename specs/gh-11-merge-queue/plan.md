# Implementation Plan: Safely Queue Parallel Pull Requests

**Branch**: `symphony/gh-11-merge-queue` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/gh-11-merge-queue/spec.md`

## Summary

Add a GitHub-backed merge queue that admits approved Symphony-managed pull requests while allowing their issue workspaces and reviews to continue independently. One OTP coordinator owns queue advancement for each configured repository and target branch. Queue order, dependency declarations, candidate revisions, and outcomes remain reconstructable from GitHub-visible pull-request/checkpoint state. The coordinator processes only the head entry, validates an exact candidate against the current target SHA, rejects stale results if either SHA changes, and merges conditionally before considering the next entry. Deterministic conflicts or validation failures return the pull request for an author update; transient provider failures retain or explicitly block the entry without misclassifying its code.

## Technical Context

**Language/Version**: Elixir 1.19 on OTP 28

**Primary Dependencies**: OTP supervision/GenServer, Req-based GitHub client, Jason, existing GitHub tracker/workflow-control and configuration abstractions

**Storage**: GitHub pull-request metadata, labels, comments/checkpoints, check runs, commit statuses, and refs; no new Symphony database

**Testing**: ExUnit with focused queue/coordinator/client/config tests using deterministic GitHub fixtures; `make -C elixir all`

**Target Platform**: Long-running Linux/macOS Symphony service using the GitHub Issues adapter with GitHub App or PAT authentication

**Project Type**: Elixir/OTP service and CLI

**Performance Goals**: Process one final integration at a time per repository/target branch; discover admission and state changes on the next configured poll; avoid rewriting non-head branches and avoid queue API calls where the feature is disabled

**Constraints**: Polling rather than webhooks; one authoritative owner per repository/target branch; GitHub-visible restart recovery; exact head/base freshness; host-side credentials; repository approvals/checks/merge rules remain authoritative; no continuous rebases; no cross-repository dependencies

**Scale/Scope**: One configured GitHub repository with independent queues per target branch, tens of concurrently open/reviewed pull requests, and dependency chains within that repository

## Constitution Check

*GATE: Passed before Phase 0 and re-checked after Phase 1 design.*

- **I. Specification and Contract Alignment — PASS**: The plan preserves the root contract's tracker, workspace, safety, and observability rules and explicitly updates `SPEC.md`, root/operator documentation, and the reusable workflow contract for serialized merging.
- **II. Workspace and Credential Safety — PASS**: Final integration is a host-owned GitHub operation. Tokens remain inside the existing GitHub client/auth boundary; the queue never executes an agent in the source checkout or another issue workspace.
- **III. Lifecycle and Recovery Correctness — PASS**: The contract covers startup reconstruction, reload/config disablement, admission, repeated polls, stale candidates, retry, deterministic incompatibility, cancellation, closure, restart after merge, and partial provider failure. GitHub-visible state and conditional SHA checks make transitions idempotent.
- **IV. Simplicity and Clear Ownership — PASS**: A single `MergeQueue` OTP process owns all configured queue keys and allows only one active candidate per key. This is smaller than one worker per pull request or a second persistence layer; provider access remains behind `GitHub.Client`.
- **V. Evidence-Driven Validation — PASS**: Implementation tasks must start with focused failing tests for ordering, stale validation, dependency gating, recovery, and duplicate-merge prevention, followed by targeted checks and `make -C elixir all`. Public functions require adjacent `@spec` declarations.
- **VI. Operational Observability — PASS**: Stable queue lifecycle logs include repository, target branch, pull-request number, originating issue when known, and candidate SHAs while excluding credentials and raw provider payloads. Documentation includes operator recovery.
- **Post-design re-check — PASS**: The data model and contract retain one owner, provider-visible durability, host-mediated credentials, lifecycle coverage, narrow scope, and required documentation/testing. No exception is required.

## Architecture and Lifecycle

1. GitHub workflow control turns a formal approval with no unresolved change request into a durable queue-admission checkpoint for the managed pull request rather than permitting an immediate agent merge.
2. `GitHub.MergeQueue` is supervised once and derives queue keys from configured repository plus each admitted pull request's target branch. It reconstructs eligible entries from GitHub on startup and every poll; it keeps timers and an active-operation cache only as accelerators, never as durable truth.
3. Admission records the pull-request number, exact head SHA, target branch, admission time/sequence, approval/check evidence, and declared dependencies in a GitHub-visible checkpoint. Stable ordering is admission sequence then pull-request number; satisfied dependency order takes precedence.
4. For each queue key, the coordinator selects at most one eligible head. It re-reads PR, review, checks, mergeability, dependencies, and current target SHA before constructing an integration candidate `(head_sha, target_sha)`.
5. At final integration only, the coordinator requests GitHub's guarded update-branch operation using the expected admitted head SHA. This creates a candidate head incorporating the current target without continuously rewriting non-head branches. Required checks run on that exact updated head, whose source head, target SHA, and resulting candidate SHA are recorded durably.
6. Before merge, the coordinator re-reads the PR head, target SHA, approvals, required checks, and repository policy. Any change invalidates the candidate. A merge request includes the expected head SHA; success is reconciled from GitHub before queue advancement.
7. A deterministic conflict or candidate check failure records an update-required outcome and removes the entry from the active path. A new head must regain current eligibility before readmission. Transient API/check infrastructure failures are retried with bounded backoff or surfaced as an operator blocker without demanding an author update.
8. Dependencies are explicit PR-number links in a repository-visible declaration. Unsatisfied prerequisites hold an entry; merged prerequisites unlock it; missing, cross-repository, closed-unmerged, or cyclic relationships produce actionable blocked outcomes.
9. Closure, approval dismissal, label removal, head changes, cancellation, target movement, partial merge responses, and restart are reconciled from GitHub before any mutation. Later independent entries advance after terminal or update-required outcomes.

## Project Structure

### Documentation (this feature)

```text
specs/gh-11-merge-queue/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── merge-queue.md
└── tasks.md                 # generated after plan approval
```

### Source Code (repository root)

```text
SPEC.md
README.md
.symphony/
├── README.md
└── WORKFLOW.md
elixir/
├── README.md
├── docs/
│   ├── github-workflow-control.md
│   └── logging.md
├── lib/symphony_elixir/
│   ├── agent_runtime_supervisor.ex
│   ├── config.ex
│   ├── config/schema.ex
│   └── github/
│       ├── client.ex
│       ├── merge_queue.ex
│       └── workflow_control.ex
└── test/symphony_elixir/
    ├── github_adapter_test.exs
    ├── github_merge_queue_test.exs
    ├── github_workflow_control_test.exs
    └── workspace_and_config_test.exs
```

**Structure Decision**: Extend the existing GitHub provider boundary with one focused coordinator. `WorkflowControl` owns durable admission/outcome checkpoint semantics, `Client` owns GitHub reads and conditional mutations, and `MergeQueue` alone owns ordering and integration decisions. The generic issue orchestrator and per-issue workspaces remain unchanged; configuration continues through `SymphonyElixir.Config`.

## Phase 0: Research

Research resolves ownership, provider-visible ordering, candidate construction, freshness/merge atomicity, dependency representation, and transient-failure classification. Decisions and rejected alternatives are recorded in [research.md](research.md).

## Phase 1: Design and Contracts

- [data-model.md](data-model.md) defines queue entries, dependency links, integration candidates, outcomes, identity rules, and transitions.
- [contracts/merge-queue.md](contracts/merge-queue.md) defines admission, ordering, validation, conditional merge, recovery, dependency, and observability behavior.
- [quickstart.md](quickstart.md) defines runnable validation scenarios for sequential success, target movement, incompatibility, re-entry, dependencies, restart, cancellation, and transient failures.

## Complexity Tracking

No constitution violations or justified complexity exceptions.
