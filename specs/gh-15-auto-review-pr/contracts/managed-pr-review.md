# Managed Pull Request Review Contract

## Producer

Before automatic review, the issue workflow MUST create/update one same-repository PR, push the exact head, add `symphony` idempotently, and write `state=review_pending`, `phase=review`, `pr_number`, `branch`, `head_sha`, and its audit summary. The write rejects invalid/mismatched PR identity, head, repository, or required label.

## Consumer

- A valid unconsumed `review_pending` checkpoint yields one automatic trigger without human input.
- Repeated derivation while claimed/running never creates a concurrent worker.
- Durable consumption or a later checkpoint prevents the generation from triggering again.
- Issue label removal/closure or PR closure/merge suppresses automatic review.

## Context enrichment

For `review_pending` and `awaiting_review`, the adapter supplies current PR/merge metadata; all paginated conversation, inline comments, and reviews; and current-head checks including pending, failed, errored, cancelled, skipped, and passing results. Required-context retrieval failure blocks dispatch instead of silently presenting an incomplete surface.

## Automatic review

The resumed agent reads issue/PR context, complete diff, contracts, and checks; reviews correctness, security, lifecycle, tests, docs, scope, and governance; reproduces and corrects in-scope findings on the same branch; distinguishes PR failures from external ones; runs targeted and full validation; pushes through the host tool; and records evidence, omissions, and blockers.

It MUST NOT broaden scope, create a second PR, expose secrets, bypass human approval, or merge solely on its own review.

## Completion

Success writes `awaiting_review` for the same PR with fresh event cursors. A blocker writes `blocked` with exact recovery action. Later review events retain existing revision semantics and only events newer than the cursor are actionable.
