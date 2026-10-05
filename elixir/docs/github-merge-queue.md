# GitHub merge queue

The optional GitHub merge queue lets development and review proceed in parallel while final
integration remains serialized per repository and target branch.

## Admission and ordering

A formal approval becomes a provider-visible `merge_queued` checkpoint containing the PR number,
approved head SHA, target branch, stable admission sequence, and dependency PR numbers. The
generation identity is `{pr_number, head_sha}`. Repeated polls cannot execute the same generation
twice. Entries use admission sequence then PR number as a stable tie-breaker; prerequisites take
precedence.

Dependencies must name PR numbers in the same repository. Missing, self-referential,
closed-unmerged, cross-repository, or cyclic links hold only the affected stack. After every
prerequisite merges, the dependent gets a new candidate against the resulting target.

## Final integration

Only the active queue head may receive an update-branch request. It carries the expected admitted
head SHA. The coordinator records the current target and resulting candidate SHA, waits for checks
on that candidate, then re-reads the PR head, target, approvals, and eligibility. It submits a
merge only if all evidence remains fresh and includes the candidate SHA as the expected head.

## Outcomes and recovery

- A merge conflict or deterministic check failure records `merge_update_required`, lets
  independent successors advance, and waits for a new approved head generation.
- Rate limits, timeouts, and check infrastructure failures retain the entry and retry with bounded
  exponential backoff. Unknown mergeability or ambiguous merge responses produce an operator hold.
- Closure, approval dismissal, label removal, or cancellation makes the generation ineligible.
  Restart reconstructs admissions from checkpoints; in-memory timers are only accelerators.

Queue logs use the stable prefix `GitHub merge queue` and include outcome, repository, target, PR,
and revision context when applicable. They never include tokens or raw provider payloads.
