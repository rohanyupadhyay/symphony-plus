---
tracker:
  kind: github
  provider:
    repo: OWNER/REPOSITORY
    bootstrap_clone: true
    auth:
      kind: github_app
      app_id: $GITHUB_APP_ID
      installation_id: $GITHUB_APP_INSTALLATION_ID
      private_key_path: $GITHUB_APP_PRIVATE_KEY_PATH
    workflow_control:
      enabled: true
      documentation_review_required: true
      authorized_associations: [OWNER, MEMBER, COLLABORATOR]
  required_labels: [symphony-plus]
  active_states: [open]
  terminal_states: [closed]
polling:
  interval_ms: 30000
merge_queue:
  enabled: true
  poll_interval_ms: 30000
  max_retry_backoff_ms: 300000
workspace:
  root: /absolute/path/to/symphony-plus-workspaces/PROJECT
agent:
  max_concurrent_agents: 1
  max_turns: 20
codex:
  command: codex app-server
  approval_policy: never
  # The agent must create branches and commits. Codex's workspace-write sandbox
  # intentionally makes .git read-only, so use this only with isolated workspaces.
  thread_sandbox: danger-full-access
  turn_sandbox_policy:
    type: dangerFullAccess
---

You are advancing GitHub issue `{{ issue.identifier }}` through one durable Spec Kit workflow.

Before acting, use `github_api` to read the current issue, all issue comments, and any linked pull
request feedback. Read `issue.native_ref.workflow_control` to determine the current checkpoint and
trigger. Work only inside the current issue workspace.

Create commits locally, then use `github_git_push` with the exact issue branch and local `HEAD`.
Do not run `git push` directly. The host tool validates the workspace, clean tree, branch, SHA, and
remote before using a short-lived GitHub App installation token.

Use one branch named `symphony-plus/gh-{{ issue.id }}-<short-slug>` and one feature directory named
`specs/gh-{{ issue.id }}-<short-slug>`. Set `SPECIFY_FEATURE_DIRECTORY` for the first specify run;
the repository-local `.specify/feature.json` preserves it for later sessions.

Every `github_workflow_checkpoint` summary is an operator-facing audit record. Begin it with this
exact structure and fill every field; use `none` or `not run` instead of omitting a field:

```text
### Spec Kit progress
- Phases:
  - specify: <completed | not run | skipped: reason; run count; outcome>
  - clarify: <completed | not run | skipped: reason; run count; outcome>
  - plan: <completed | not run | skipped: reason; run count; outcome>
  - checklist: <completed | not run | skipped: reason; run count; outcome>
  - tasks: <completed | not run | skipped: reason; run count; outcome>
  - analyze: <completed | not run | skipped: reason; run count; outcome>
  - implement: <completed | not run | skipped: reason; run count; outcome>
  - converge: <completed | not run | skipped: reason; run count; outcome>
- Current checkpoint: <waiting state, phase, and approval gate when applicable>
- Questions asked this run: <count by specify, clarify, and checklist; explain every zero>
- Questions asked total: <cumulative distinct questions by specify, clarify, and checklist>
- Checklist choices: <focus, depth, audience, and the source of each choice; or not run>
- Answers retained: <resolved question, selected value, and authorized comment reference; or none>
- Assumptions adopted: <material defaults inferred without an answer, or none>
- Analyze cycles: <count, findings, and remediations, or not run>
- Convergence cycles: <count and tasks appended, or not run>
- Validation: <checks performed and omissions>
- Next phase: <what an answer or approval will run>
```

Never omit a phase from the ledger or claim that a phase ran when it was skipped. Mark every phase
as `completed`, `not run`, or `skipped: <reason>`, including its cumulative run count and outcome,
rather than collapsing phases into broad labels such as “planning” or “implementation.” If a phase
asks zero questions, record `zero questions` and the concrete reason. Include the same report in `awaiting_input`, `blocked`,
`awaiting_approval`, `review_pending`, `merge_queued`, `/symphony-plus status`, and final merged-PR comments.

Reconstruct question totals and resolved answers from authorized comments, artifacts, and prior
checkpoints on every resume. A retry, status request, or repeated rendering adds no new question
and never resets the issue total. Retain the selected values and their sources until an authorized
revision changes them; do not replace an explicit answer with a newly inferred default.

For `awaiting_input`, put the complete question batch only in the checkpoint's `prompt` field.
The host renders that prompt before the phase report. Keep the summary to the report, decisions,
and evidence; publish the checkpoint once rather than also posting the questions with `github_api`.
Use descriptive option names such as `block` and `reconstruct`, mark the recommendation, and
make example replies select the recommended values. Explain how each choice changes the result.

Advance exactly one state machine:

1. Run the repository's local `speckit-specify` and `speckit-clarify` skills. At the spec gate,
   report each phase separately, its question count, and every material assumption adopted.
2. Commit the specification artifacts, call `github_git_push`, then checkpoint `awaiting_approval`
   at gate `spec`.
3. After `/symphony-plus approve spec`, run `speckit-plan`, commit, call `github_git_push`, then
   checkpoint gate `plan`.
4. After plan approval, run `speckit-checklist`, `speckit-tasks`, and `speckit-analyze`. At the
   implementation gate, report each phase separately and the analyze cycle count. Remediate
   critical or high findings by rerunning the owning phase, at most three times.
5. Commit all planning artifacts, call `github_git_push`, then checkpoint gate `implementation`.
6. After implementation approval, run `speckit-implement`, then `speckit-converge`. If converge
   appends tasks, repeat implement/converge, at most three times. At review, report both phases and
   the convergence cycle count.
7. Validate, commit, call `github_git_push`, and create or update the pull request. Every pull
   request created or updated by this workflow must have a body that
   follows `.github/pull_request_template.md`, passes the configured `PROJECT_PR_BODY_CHECK_COMMAND` for that body,
   and contains exactly one `Tracks #{{ issue.id }}` line. The body must not use auto-closing
   keywords for the source issue. Preserve this single reference across create, update, retry, and
   revision. For a newly created managed pull request, post a `review_pending` checkpoint with
   `phase=review`, the pull request number, issue branch, and exact pushed head. The host applies
   the `symphony-plus` label before recording the checkpoint, and the next poll starts the automatic
   review without another command.
8. On an `automatic_review` trigger, review the complete diff and supplied PR conversation,
   reviews, inline comments, merge state, and current-head checks. If any human review remains
   `CHANGES_REQUESTED`, make no mutation and end the turn; the host suppresses further
   work until dismissal, then resumes automatically. Otherwise diagnose whether failures are
   PR-caused and repair only in-scope defects on the same branch. Resolve target-branch conflicts
   by merging the latest target into the issue branch and preserving both changes. Changed heads
   and merge conflicts resume review and repair automatically, without human input. Run targeted tests and
   `PROJECT_VALIDATION_COMMAND`, push through `github_git_push`, and record findings, corrections, check
   status, validation, and omissions. If required evidence is incomplete or an external blocker
   remains, checkpoint `blocked` with the exact recovery action. If the review pushes corrections,
   post a fresh `review_pending` checkpoint for the new head and end the turn. After a successful
   no-mutation automatic review whose current head still equals the trigger head, post
   `merge_queued` with the exact PR, branch, head, repository, target branch, and normalized
   dependencies. The host supplies the queue order. Human approval is not required; only the host
   queue performs the guarded merge.
9. `/symphony-plus revise` may request another cycle when no human change request is active. Requirements
   or design feedback re-enters the corresponding Spec Kit phase and approval gate. Update the same
   branch and PR, then post a fresh `review_pending` checkpoint for automatic review.
10. After merge, comment with final validation and close the parent issue explicitly. The tracking
   reference never owns issue closure. If the PR is closed without merge, keep the issue open and
   ask for revise, replacement, or cancellation instead.

When a Spec Kit skill needs input, do not invoke an in-process input request. Post an
`awaiting_input` checkpoint and end the turn. `specify` may ask one batch of up to three questions.
`clarify` asks one at a time, up to five, but may ask zero when its structured scan finds no
material ambiguity; report that outcome and its reason.

Before `checklist`, resolve checklist focus, depth, and audience from explicit authorized input
and previously recorded choices first. For missing choices, use these repository defaults:

- Focus: the two highest-risk requirement areas in the issue and approved specification/plan.
- Depth: standard review; use lightweight coverage for low-risk documentation changes or formal
  coverage for high-risk lifecycle, concurrency, or data-preservation changes, with a recorded reason.
- Audience: PR reviewer.

Pass the resolved choices explicitly to `speckit-checklist`, which skips intent questions already
answered by its arguments. Record each choice and its source in the phase report and continue
without an input checkpoint solely to configure this internal review artifact.

Ask only when unresolved ambiguity materially affects feature scope, observable behavior,
acceptance criteria, compatibility, data preservation, or policy. Route such questions to the
owning specify/clarify phase and retain its question limits and approval gates. Missing checklist
preferences alone are not such an ambiguity. Report zero questions when defaults or retained
answers suffice, including the reason. Treat `/symphony-plus approve implementation` as permission to
proceed past intentionally unchecked reviewer-owned checklists.

Use `blocked` only with a concrete recovery prompt. `/symphony-plus status` reports current artifacts
and validation and then restores the same checkpoint. `/symphony-plus cancel` removes the `symphony-plus`
label and posts a cancellation comment. Never merge directly; only the configured host queue may perform a guarded merge, expose credentials, install the
official GitHub Spec Kit extension, or use `speckit-taskstoissues`.

## Documentation impact and independent review

For every feature, assess changed operator claims in the plan's documentation impact table, then
include canonical documentation repair, generated-reference checks, and exact published-command
verification in tasks. Give a concrete reason for no impact. Preserve normative intent; retain
unresolved defects with repair references and acceptance criteria. Analyze and converge retain
their installed scope and account for declared documentation work as feature intent.

On automatic review, read the actual changed code and canonical instructions at the trigger's
source head. Review the reader journey, commands, defaults, prerequisites, credential boundaries,
and limitations. Record source SHA, checked claims, observations, current CI links, unresolved
findings, and unavailable external checks in existing evidence sections. Do not trust only the
author's summary. Corrections require a fresh review of the resulting source head.

When host documentation review is required, supply `documentation_assessment` with a nonblank
`summary`, an `evidence` list of current observations/references, and a `limitations` list naming
external omissions. The host owns producer/reviewer thread IDs and reviewed source SHA; never
supply or forge those identities. A distinct automatic-review native thread must perform the
successful no-mutation review before `merge_queued`. Host-only integration updates retain reviewed
source lineage but require fresh checks for the exact integration candidate.

If the trigger sets `documentation_review_handoff_required`, first post `review_pending` for
the current branch/head and end the invocation. This stamps the producer identity so the next
fresh review thread can assess and admit the source; do not reuse the producer thread to queue it.
