# Quickstart: Validate Automatic Managed-PR Review

## Prerequisites

- GitHub workflow control enabled with required label `symphony`
- GitHub App permissions for contents, issues, PRs, and workflows
- Disposable repository/fixture with the Spec Kit workflow
- Elixir 1.19 / OTP 28 through `mise`

## Focused validation

```bash
cd elixir
mise exec -- mix test \
  test/symphony_elixir/github_workflow_control_test.exs \
  test/symphony_elixir/github_adapter_test.exs \
  test/symphony_elixir/github_launcher_test.exs
```

Expected: valid pending review dispatches once; malformed, unlabeled, forked, closed, merged, or mismatched PRs do not; restart recovery avoids duplicate concurrent work; context includes paginated review surfaces/current-head checks; successful review returns to `awaiting_review` with fresh cursors.

Implementation evidence (2026-10-03): 43 focused workflow-control, adapter, and launcher tests
passed. They cover schema validation, label-before-checkpoint ordering, exact managed-PR identity,
next-poll dispatch, later-checkpoint consumption, terminal/fork/cross-repository/label/head
suppression, current-head check/status enrichment, fresh review cursors, and the originating issue
workspace prompt contract. The first convergence pass found missing lifecycle observability; T030
added stable handoff, dispatch/suppression, and enrichment-failure logs with issue/PR context.

## End-to-end path

1. Label an issue `symphony` and approve through implementation.
2. Let Symphony create the PR; observe its label before `review_pending` is recorded.
3. Post no command and wait for the next successful poll.
4. Observe one worker resume in the originating issue workspace and inspect the same PR.
5. Observe repairs/validation update the same branch/PR and an `awaiting_review` checkpoint.
6. Confirm the PR remains unmerged for human review.

## Recovery and failure scenarios

Restart after PR creation, label application, checkpoint write, and during review. Retry recoverable operations and confirm one label, one PR, one writer, and no repeated initial generation. Exercise PR-caused and external failing checks, issue-label removal, issue closure, PR close/merge, and later formal changes.

## Full gate

```bash
make -C elixir all
```

Review the diff for secrets, unrelated changes, generated artifacts, contract drift, incomplete tasks, and missing documentation.

Full-gate evidence (2026-10-03): `mix test --cover` passed 368 tests with 6 skipped and 100.00%
coverage. The first `make -C elixir all` attempt exposed uncovered negative branches, which were
remediated with focused tests. Dependency setup reported existing Hex advisories, including HIGH
advisories for Bandit, hpax, Mint, Phoenix, Plug, and Req; this feature does not change dependency
versions, and the advisory output must be retained in the pull-request handoff.
