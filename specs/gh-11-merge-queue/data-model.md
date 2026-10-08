# Data Model: Safely Queue Parallel Pull Requests

## Queue Key

- `repository`: configured `owner/repo`
- `target_branch`: pull request base ref

**Identity**: `(repository, target_branch)`.

**Invariant**: At most one integration candidate for a queue key may be validating or merging at a time.

## Queue Entry

- `pull_request_number`: positive same-repository PR number
- `originating_issue_number`: Symphony issue number when managed by the durable workflow
- `head_sha`: exact 40-character head admitted to the queue
- `target_branch`: base ref
- `admitted_at`: provider event timestamp
- `admission_sequence`: stable provider event/comment identifier; PR number breaks ties
- `state`: `queued`, `held_dependency`, `validating`, `merge_ready`, `update_required`, `transient_blocked`, `cancelled`, or `merged`
- `prerequisites`: normalized unique PR-number list
- `eligibility_evidence`: trusted automatic-review, human change-request, required-check, label, open-state, and repository-policy evidence
- `latest_outcome`: validation/merge outcome, reason, and recovery action

**Identity**: `(repository, pull_request_number, head_sha, admission_sequence)`.

An updated head is a new generation. It does not inherit candidate validation or queue admission eligibility from the prior generation.

## Dependency Relationship

- `dependent_pr`: queue-entry PR number
- `prerequisite_pr`: same-repository PR number
- `status`: `unmerged`, `merged`, `missing`, `closed_unmerged`, `cross_repository`, or `cyclic`

**Validation rules**:

- Self-dependencies and duplicate edges are invalid or normalized away as appropriate.
- Every prerequisite must resolve in the same repository.
- A dependency is satisfied only by a merged prerequisite.
- Cycles are detected over all active declared edges and hold every affected entry with an actionable outcome.

## Integration Candidate

- `pull_request_number`
- `source_head_sha`: exact reviewed source revision admitted before final integration
- `target_sha`: exact target revision used to build the candidate
- `candidate_sha`: resulting queue-head revision after guarded final-integration update
- `created_at`
- `validation_state`: `pending`, `passing`, `deterministic_failure`, `transient_failure`, `stale`, or `cancelled`
- `required_check_evidence`: check names, conclusions, and candidate SHA

**Identity**: `(repository, target_branch, pull_request_number, source_head_sha, target_sha)`.

**Freshness invariant**: Candidate construction is valid only when the guarded update starts from `source_head_sha`. After the update, a candidate is mergeable only while the current PR head equals `candidate_sha`, the current target equals `target_sha`, dependency state remains satisfied, and repository eligibility remains current. The conditional merge supplies `candidate_sha` as its expected PR head.

## Queue Outcome

- `kind`: `merged`, `update_required`, `transient_retry`, `operator_blocked`, `cancelled`, or `stale`
- `reason`: stable concise classification
- `detail`: bounded non-secret explanation
- `recovery_action`: author or operator action, if any
- `observed_head_sha`, `observed_target_sha`, `candidate_sha`
- `recorded_at`

Outcome writes are idempotent for the candidate identity. An ambiguous merge response is never retried until provider state proves whether the PR merged.

## State Transitions

```text
auto-reviewed/current head
  -> queued
  -> held_dependency -> queued
  -> validating
  -> stale -> validating (new target candidate)
  -> merge_ready
  -> merged

validating
  -> update_required (conflict or deterministic check failure)
  -> transient_blocked -> validating (retry/recovery)
  -> held (human changes requested; resumes when dismissed)
  -> cancelled (closed, label removed, or explicit cancellation)

update_required
  -> queued only after a new head has current checks and trusted automatic review
```

## Reconstruction and Cleanup

- GitHub-visible checkpoints and pull-request state are the durable source of truth.
- Startup/restart scans admitted nonterminal entries and reconciles current provider state before selection.
- A stale candidate head never authorizes merge; a later target advance requires another guarded final-integration update and fresh checks.
- A recorded successful merge dominates stale local or checkpoint state and advances the queue exactly once.
