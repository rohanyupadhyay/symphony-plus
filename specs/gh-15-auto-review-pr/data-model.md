# Data Model: Automatically Review Symphony Pull Requests

## Originating Issue

Existing normalized issue and sole scheduler identity: stable `id`, GitHub `number`, `repo`, normalized `labels`, `state`, `workflow_control`, and deterministic `workspace_key`.

**Invariant**: Only this issue identity may own a running worker and mutate its managed PR branch.

## Managed Pull Request

- `number`: positive GitHub PR number
- `repo`: equal to the originating issue repository
- `branch`: exact issue branch matching policy
- `head_sha`: 40-character pushed commit SHA
- `base_branch`: `main`
- `labels`: includes `symphony` before dispatch
- `state`: open or closed
- `merged`: boolean
- `created_by_workflow`: established by the issue's durable checkpoint, not author or text

Fork/cross-repository heads are ineligible. Branch/head must match the managed PR. Only one PR is authoritative per issue review cycle.

## Review Cycle

- `phase`: `review`
- `state`: `review_pending`, `awaiting_review`, or `blocked`
- `pr_number`, `branch`, `head_sha`: managed PR identity and reviewed revision
- `cursor`: event IDs and automatic-dispatch consumption metadata
- `summary`: operator audit report
- `prompt`: required recovery action when blocked

**Identity**: `(originating_issue_id, pr_number, review generation)`.

## Review Evidence Snapshot

- current `pull_request` metadata and merge state
- paginated `conversation_comments`, `review_comments`, and formal `reviews`
- current-head `checks`
- maximum handled event IDs in `cursor`

Checks are classified by the workflow as `passing`, `pending`, `pr_caused_failure`, `external_or_flaky`, or `blocked_or_unavailable`.

## Review Finding

A workflow audit item with `severity`, reproducible `evidence`, `disposition` (corrected, non-actionable, deferred-for-authorization, or blocked), and targeted/full-gate `validation`. It needs no new Symphony persistence.

## State Transitions

```text
implementation approved
  -> PR created/updated and branch pushed
  -> PR label applied
  -> review_pending (durable; automatically dispatchable once)
  -> automatic review running (originating issue owns worker)
  -> awaiting_review (human handoff with fresh cursors)

review_pending or automatic review running
  -> blocked (external/permission/scope blocker)
  -> closed/merged/label removed (stop or reconcile; no new work)

awaiting_review
  -> implementation revision (new authorized feedback/check event)
  -> awaiting_review (fresh handoff)
  -> merged or closed handling
```

## Idempotency Rules

- Existing labels are not duplicated.
- The same pending generation is never dispatched concurrently.
- Restart reconstruction yields the same eligibility decision.
- A later checkpoint supersedes older comments permanently.
- Events at or below handoff cursors never trigger another revision.
