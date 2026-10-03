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
