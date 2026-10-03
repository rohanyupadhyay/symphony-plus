# Research: Automatically Review Symphony Pull Requests

## Durable automatic-dispatch signal

**Decision**: Add a GitHub-visible `review_pending` workflow checkpoint that contains the managed pull request number, branch, and exact pushed head. Dispatch it once without requiring a human event, and durably record consumption through subsequent checkpoint progression.

**Rationale**: Existing checkpoints already provide restart recovery and authorization boundaries. A distinct state makes the automatic transition explicit and testable without interpreting prose, authorship, or a label alone.

**Alternatives considered**: Leaving the issue uncheckpointed loses explicit phase/PR identity after a crash. Overloading `awaiting_review` confuses human handoff with automatic work. Webhooks or a database exceed the repository's polling and GitHub-visible recovery model.

## Scheduling identity and mutation ownership

**Decision**: Continue scheduling the originating issue ID and reuse its workspace, claim, branch, and session-continuation rules. The pull request is context attached to that workflow, not a second schedulable tracker item.

**Rationale**: The orchestrator already enforces one running entry per issue. Preserving that identity prevents issue and PR workers from writing the branch concurrently and keeps terminal cleanup deterministic.

**Alternatives considered**: A synthetic PR issue duplicates ownership, workspace, routing, and retry state. A separate PR orchestrator violates the smallest-coherent-design constraint.

## Label and checkpoint ordering

**Decision**: After the managed pull request exists and its branch head is pushed, apply the configured required label idempotently, then write `review_pending`. A failed label or checkpoint write leaves a recoverable, observable partial state and must not claim successful handoff.

**Rationale**: The pull request must be visibly eligible before automatic review is advertised. Label addition and checkpoint comments are safe to retry.

**Alternatives considered**: Writing the checkpoint before labeling can start review with incomplete eligibility. Inferring managed identity from author or body text is ambiguous and forgeable.

## Review context and checks

**Decision**: Extend review enrichment for `review_pending` and include PR metadata, conversation, inline comments, formal reviews, check runs/statuses for the checkpoint head, and merge state. Keep investigative API calls available through `github_api`.

**Rationale**: Automatic review needs a stable initial snapshot, while the generic tool supports drill-down without hard-coding review policy into orchestration. Head-SHA scoping avoids stale checks.

**Alternatives considered**: Putting review logic in the adapter violates policy ownership. Depending only on agent discovery leaves eligibility and terminal reconciliation unstructured.

## Review method

**Decision**: Define an evidence-driven workflow: read all review surfaces and the diff, challenge correctness/security/lifecycle/testing/docs/scope, reproduce failures, make authorized changes, run targeted tests and the full gate, and report omissions/blockers.

**Rationale**: Repository governance remains the baseline; Codex review capabilities may assist but do not replace reproducible evidence.

**Alternatives considered**: A vendor-specific review command may be unavailable. Passing checks alone cannot cover all review concerns.

## Human handoff and later events

**Decision**: Successful automatic review ends in existing `awaiting_review` with fresh event cursors. Formal changes, approvals, close/merge, and explicit revision commands retain their semantics.

**Rationale**: This preserves human approval and merge policy while preventing old events from redispatching work.

**Alternatives considered**: Automatic merge violates governance. Another handoff state duplicates `awaiting_review`.
