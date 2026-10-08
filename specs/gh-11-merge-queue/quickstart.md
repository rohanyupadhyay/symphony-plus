# Quickstart: Validate the Merge Queue

## Prerequisites

- Elixir 1.19 / OTP 28 dependencies installed for `elixir/`
- A GitHub test repository or deterministic request fixture with merge-queue configuration enabled
- Branch protection/check fixtures representing required approval and status policy

Run focused tests from `elixir/` as the scenarios are implemented, then run the full gate:

```bash
mix test test/symphony_elixir/github_merge_queue_test.exs
mix test test/symphony_elixir/github_workflow_control_test.exs test/symphony_elixir/github_adapter_test.exs
make all
```

## Scenario 1: Sequential current-target integration

1. Admit three successfully auto-reviewed managed pull requests for `main` while development overlaps.
2. Assert only the first stable queue entry receives an active candidate.
3. Complete required checks and merge it.
4. Assert the second candidate records the new `main` SHA, then repeat for the third without human approval.

Expected: no candidate validation or merge overlaps for the queue key, and every successful merge records exact current head/target evidence.

## Scenario 2: Target changes during validation

1. Begin candidate validation for a queued pull request.
2. Advance `main` externally before the merge decision.
3. Complete the old candidate checks successfully.

Expected: the old result is stale, no merge occurs, and a new candidate is created against the advanced target.

## Scenario 3: Conflict and deterministic check failure

1. Put two independent entries in the queue.
2. Make the head conflict with current `main`, or fail a required candidate check deterministically.

Expected: the head receives an actionable `update_required` outcome, is removed from the active path, and the independent second entry advances.

## Scenario 4: Updated-head re-entry

1. Push a new head to the removed pull request.
2. Leave old checks or approvals attached only to the prior SHA.
3. Supply current automatic-review and check evidence for the new SHA.

Expected: no readmission occurs until evidence is current; afterward exactly one new queue generation is admitted.

## Scenario 5: Dependency ordering and invalid graphs

1. Admit a dependent PR before its declared prerequisite.
2. Assert the dependent remains held until the prerequisite merges.
3. Exercise a longer chain, a cycle, a missing PR, a cross-repository link, and a closed-unmerged prerequisite.

Expected: valid chains merge prerequisite-first and revalidate each dependent afterward; invalid relationships produce specific blockers and never guessed ordering.

## Scenario 6: Restart and partial merge response

1. Stop the coordinator with an entry validating, then restart it.
2. Repeat with a merge request whose response is lost after GitHub applies the merge.

Expected: provider-visible state reconstructs the same queue/candidate decision; reconciliation detects the completed merge and never submits a duplicate.

## Scenario 7: Cancellation and eligibility loss

During validation, close the PR, submit or dismiss a human change request, remove its eligibility label, change its head, or cancel it through workflow control.

Expected: an active human change request causes no Symphony mutation and dismissal resumes automatically; other eligibility loss prevents merge and lets another eligible entry advance safely.

## Scenario 8: Transient provider/check failure

Return rate limiting, timeout, unknown mergeability, or check-infrastructure failure while candidate validation is active.

Expected: the entry is retried with bounded backoff or explicitly operator-blocked; it is not labeled incompatible and its author is not asked to rewrite the branch.

## Validation Record

Validated on 2026-10-05 with deterministic ExUnit fixtures:

- Scenarios 1–8: covered by `github_merge_queue_test.exs`, `github_merge_queue_state_test.exs`, `github_client_test.exs`, and `github_workflow_control_test.exs`.
- Focused command: `mix test test/symphony_elixir/github_merge_queue_state_test.exs test/symphony_elixir/github_client_test.exs test/symphony_elixir/github_workflow_control_test.exs test/symphony_elixir/github_merge_queue_config_test.exs test/symphony_elixir/github_merge_queue_test.exs test/symphony_elixir/core_test.exs` — 83 tests, 0 failures before convergence remediation; subsequent focused recovery suite — 32 tests, 0 failures.
- Public-spec command: `mix specs.check` — passed.
- Intentional omissions: no live GitHub repository mutation was performed; conditional update, checkpoint comment, status/review reads, and merge requests use deterministic client/backend fixtures so validation cannot merge a real pull request.
- Full gate: recorded by task T038 after the final `make -C elixir all` run.
