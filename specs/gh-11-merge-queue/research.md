# Research: Safely Queue Parallel Pull Requests

## Decision: Use one OTP coordinator for all repository/target queue keys

**Rationale**: Final integration is cross-issue state. Existing issue workers correctly own individual workspaces but cannot serialize decisions across sibling pull requests. One supervised coordinator can enforce the invariant that each `(repository, target_branch)` has at most one active integration candidate while keeping issue execution parallel.

**Alternatives considered**:

- Reuse issue-worker concurrency: rejected because separate issues can validate and merge concurrently.
- Start one queue process per pull request: rejected because ownership and ordering would be distributed and recovery races would multiply.
- Set global issue concurrency to one: rejected because it destroys the required parallel development/review behavior and still does not make merge evidence durable.

## Decision: Keep durable truth in GitHub-visible state

**Rationale**: Admission order, exact revisions, dependency declarations, validation outcomes, and recovery actions must survive service restart and be inspectable by operators. Versioned checkpoint comments and pull-request metadata fit the existing workflow-control model. The coordinator may cache active work in memory, but every decision is reconstructed and revalidated from GitHub.

**Alternatives considered**:

- Add a local database: rejected as a second authority and unnecessary operational burden.
- Persist only labels: rejected because labels cannot encode exact candidate identity, stable admission sequence, dependency detail, or failure evidence.
- Persist ordering only in memory: rejected because restart could reorder entries or lose them.

## Decision: Build an exact candidate by updating only the active queue head

**Rationale**: The required evidence is the pull-request change applied to the actual current target. Only when an entry becomes the active head, the coordinator uses GitHub's guarded update-branch operation with the expected admitted head SHA, records the current target SHA and resulting candidate head, and waits for required checks on that exact revision. This is an allowed final-integration update, avoids maintaining custom merge commits/refs, and leaves every non-head branch untouched.

**Alternatives considered**:

- Rebase every queued branch whenever the target changes: rejected because it creates review churn and violates the feature contract.
- Trust checks from the pre-integration pull-request head alone: rejected because those checks may not include changes merged ahead of it.
- Create and maintain custom temporary merge refs: rejected because GitHub already provides a guarded final-integration branch update and custom ref cleanup adds a second lifecycle without improving the safety invariant.
- Merge first and validate afterward: rejected because it cannot protect the target branch.

## Decision: Re-read both revisions and eligibility immediately before a conditional merge

**Rationale**: Validation becomes stale when the target or pull-request head changes. The coordinator therefore compares the recorded head and target SHAs with current GitHub state, rechecks human change-request, check, and policy evidence, and supplies the expected head SHA to the merge mutation. A target change forces a new candidate; an ambiguous merge response is reconciled from PR and target state before retry.

**Alternatives considered**:

- Use a time-based freshness window: rejected because even a one-second-old result may target the wrong base.
- Serialize only inside the process: rejected because external merges can advance the target.
- Retry a timed-out merge blindly: rejected because the first request may already have succeeded.

## Decision: Represent dependencies as explicit same-repository PR-number links

**Rationale**: Pull-request numbers are durable, repository-visible, and directly resolvable through the existing client. The admission checkpoint stores the normalized prerequisite list. Eligibility requires every prerequisite to be merged; cycle detection runs over queued dependency edges. Cross-repository, missing, or closed-unmerged prerequisites are invalid.

**Alternatives considered**:

- Infer dependencies from branch names or base branches: rejected because inference is ambiguous and can silently choose the wrong order.
- Use issue links as the merge dependency authority: rejected because the merge object is the pull request and issue links do not prove the prerequisite merge state.
- Support cross-repository stacks initially: rejected because there is no shared atomic target or ordering owner in the approved scope.

## Decision: Classify deterministic and transient failures separately

**Rationale**: Merge conflicts and candidate check failures tied to the current target require author action; timeouts, rate limits, and provider/check infrastructure errors do not. Deterministic outcomes remove an entry from the active path with an update-required checkpoint. Transient outcomes retain the entry for bounded retry or block it with an operator recovery action while preserving queue identity.

**Alternatives considered**:

- Treat every failure as update-required: rejected because it creates needless branch churn and misleads authors.
- Retry every failure forever: rejected because deterministic incompatibilities would deadlock the queue.
- Skip transiently failing heads immediately: rejected because an unclear provider state could permit unsafe reordering; the contract requires an explicit retry/block policy.
