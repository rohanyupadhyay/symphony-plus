# Merge Queue Contract

## Scope and ownership

The queue is enabled only for configured GitHub repositories. Exactly one supervised coordinator owns ordering and final integration decisions for each `(repository, target_branch)`. Issue workers remain independent owners of development/review workspaces and cannot merge around the coordinator.

## Admission

An open same-repository pull request is admitted only when required human approval exists, no unresolved change request exists, the current head's required checks and labels satisfy repository workflow eligibility, and its workflow records a versioned queue checkpoint. The checkpoint contains PR number, head SHA, target branch, stable admission evidence, and normalized prerequisite PR numbers.

Admission is idempotent. Repeated polls of the same generation create one entry. A changed head invalidates prior validation and requires checks/approval eligibility for the new generation before readmission.

## Ordering and dependencies

Within a queue key, independent entries order by stable admission sequence and then PR number. An entry with unmerged prerequisites is held and cannot become the active head. Merged prerequisites satisfy the edge. Missing, cross-repository, closed-unmerged, self-referential, or cyclic prerequisites produce a durable actionable blocked outcome.

Holding or removing one dependent entry does not prevent another independently eligible entry from advancing.

## Candidate validation

The coordinator selects no more than one active head per queue key. Before candidate creation it re-reads the PR head, target SHA, approvals, checks, labels, dependency state, and mergeability.

The validation candidate represents exactly the admitted change applied to the current `target_sha` and is identified by a provider-visible `candidate_sha`. Only the active queue head may receive a guarded final-integration branch update, using the expected admitted head SHA; non-head branches are never rewritten merely because the target moved. Candidate checks must be attributable to the resulting candidate SHA.

If the source cannot apply to the target or required candidate checks fail deterministically, the entry receives `update_required`, leaves the active merge path, and exposes the reason and recovery action. Provider timeouts, rate limits, incomplete mergeability calculation, and check-infrastructure failures are transient; they are retried with bounded backoff or explicitly blocked for operator recovery without demanding an author update.

## Freshness and merge

Immediately before merge the coordinator MUST confirm:

- current PR head equals the candidate head;
- current target SHA equals the candidate target;
- the candidate checks are passing for the candidate SHA;
- approvals, labels, dependencies, and repository merge policy remain satisfied;
- the PR remains open and is still the active queue head.

Any mismatch makes validation stale and prevents merge. Target movement creates a new candidate against the new target. The merge mutation supplies the expected PR head SHA. After success or an ambiguous response, the coordinator re-reads PR and target state before advancing or retrying.

## Recovery and reconciliation

Startup, repeated polls, reload, restart, cancellation, PR closure, approval dismissal, label removal, head update, target movement, merge completion, and partial provider failure all reconcile from GitHub-visible state. Terminal outcomes are idempotent. A successful merge cannot be duplicated by retry, and a stale candidate cannot authorize a later merge.

When an incompatible entry leaves the path, the next independently eligible entry may advance. The removed entry can return only as a new/current generation whose checks and approval eligibility are valid.

## Observability

Operators and authors can inspect queue state/position, dependency hold, active candidate revisions, latest validation outcome, blocker, and recovery action. Stable logs include repository, target branch, PR number, originating issue identifier when present, outcome/reason, and non-secret SHA identifiers. Credentials and raw provider payloads are never logged or persisted in checkpoints.

## Configuration and safety

Configuration is loaded through `SymphonyElixir.Config`, validates repository and polling/retry settings, and supports safe disable/reload. All GitHub calls use the existing host-side authenticated client. No queue action runs Codex outside an issue workspace, weakens branch protection, bypasses required review/check policy, or treats automated review as human approval.
