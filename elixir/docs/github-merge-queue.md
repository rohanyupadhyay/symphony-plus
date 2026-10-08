# GitHub merge queue

The optional GitHub merge queue lets development and review proceed in parallel while final
integration remains serialized per repository and target branch.

## Admission and ordering

A successful trusted automatic review of a same-repository pull request created by Symphony from
an issue becomes a provider-visible `merge_queued` checkpoint containing the PR number, reviewed
head SHA, target branch, stable admission sequence, and dependency PR numbers. Human approval is
not required. A current human `CHANGES_REQUESTED` review suspends automatic review and all queue
mutations until it is dismissed. The generation identity is `{pr_number, head_sha}`. Repeated polls
cannot execute the same generation twice. Entries use admission sequence then PR number as a stable
tie-breaker; prerequisites take precedence.

Dependencies must name PR numbers in the same repository. Missing, self-referential,
closed-unmerged, cross-repository, or cyclic links hold only the affected stack. After every
prerequisite merges, the dependent gets a new candidate against the resulting target.

## Final integration

Only the active queue head may receive an update-branch request. It carries the expected admitted
head SHA. The coordinator records the current target and resulting candidate SHA, waits for checks
on that candidate, then re-reads the PR head, target, human change-request state, and eligibility. It submits a
merge only if all evidence remains fresh and includes the candidate SHA as the expected head.

## Outcomes and recovery

- A merge conflict or deterministic check failure records `merge_update_required`, lets
  independent successors advance, and waits for a newly auto-reviewed head generation.
- Rate limits, timeouts, and check infrastructure failures retain the entry and retry with bounded
  exponential backoff. Unknown mergeability or ambiguous merge responses produce an operator hold.
- Closure, label removal, or cancellation makes the generation ineligible. A human change request
  holds the generation without consuming it; dismissal resumes processing automatically. Restart
  reconstructs admissions from checkpoints; in-memory timers are only accelerators.

Queue logs use the stable prefix `GitHub merge queue` and include outcome, repository, target, PR,
and revision context when applicable. They never include tokens or raw provider payloads.
