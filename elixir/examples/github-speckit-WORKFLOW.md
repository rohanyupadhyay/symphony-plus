---
tracker:
  kind: github
  provider:
    repo: OWNER/REPOSITORY
    auth:
      kind: github_app
      app_id: $GITHUB_APP_ID
      installation_id: $GITHUB_APP_INSTALLATION_ID
      private_key_path: $GITHUB_APP_PRIVATE_KEY_PATH
    workflow_control:
      enabled: true
      authorized_associations: [OWNER, MEMBER, COLLABORATOR]
  required_labels: [symphony]
  active_states: [open]
  terminal_states: [closed]
polling:
  interval_ms: 30000
workspace:
  root: /absolute/path/to/symphony-workspaces/PROJECT
hooks:
  after_create: |
    git clone --depth 1 https://github.com/OWNER/REPOSITORY.git .
  timeout_ms: 300000
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

Use one branch named `symphony/gh-{{ issue.id }}-<short-slug>` and one feature directory named
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
- Questions asked: <count by specify, clarify, and checklist; explain every zero>
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
`awaiting_approval`, `awaiting_review`, `/symphony status`, and final merged-PR comments.

Advance exactly one state machine:

1. Run the repository's local `speckit-specify` and `speckit-clarify` skills. At the spec gate,
   report each phase separately, its question count, and every material assumption adopted.
2. Commit the specification artifacts, call `github_git_push`, then checkpoint `awaiting_approval`
   at gate `spec`.
3. After `/symphony approve spec`, run `speckit-plan`, commit, call `github_git_push`, then
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
   follows `.github/pull_request_template.md`, passes `cd elixir && mix pr_body.check --file <path>`,
   and contains exactly one `Tracks #{{ issue.id }}` line. The body must not use auto-closing
   keywords for the source issue. Preserve this single reference across create, update, retry, and
   revision. For a newly created managed pull request, post a `review_pending` checkpoint with
   `phase=review`, the pull request number, issue branch, and exact pushed head. The host applies
   the `symphony` label before recording the checkpoint, and the next poll starts the automatic
   review without another command.
8. On an `automatic_review` trigger, review the complete diff and supplied PR conversation,
   reviews, inline comments, merge state, and current-head checks. Diagnose whether failures are
   PR-caused, repair only in-scope defects on the same branch, run targeted tests and
   `make -C elixir all`, push through `github_git_push`, and record findings, corrections, check
   status, validation, and omissions. If required evidence is incomplete or an external blocker
   remains, checkpoint `blocked` with the exact recovery action. Otherwise post a fresh
   `awaiting_review` checkpoint; never merge solely on the automated review.
9. Apply implementation-only review feedback directly. Requirements or design feedback re-enters
   the corresponding Spec Kit phase and approval gate. Update the same branch and PR.
10. After merge, comment with final validation and close the parent issue explicitly. The tracking
   reference never owns issue closure. If the PR is closed without merge, keep the issue open and
   ask for revise, replacement, or cancellation instead.

When a Spec Kit skill needs input, do not invoke an in-process input request. Post an
`awaiting_input` checkpoint and end the turn. `specify` may ask one batch of up to three questions.
`clarify` asks one at a time, up to five, but may ask zero when its structured scan finds no
material ambiguity; report that outcome and its reason. Before `checklist`, determine whether
authorized issue input already specifies checklist focus, depth, and audience. If any dimension is
missing, `checklist` must ask one initial batch of up to three questions covering the missing
dimensions; GitHub checkpoints make interaction possible, so do not silently apply its fallback
defaults. It may ask one follow-up batch of up to two only when necessary. If all three dimensions
were explicit, report zero questions and cite the controlling issue input. Treat `/symphony
approve implementation` as permission to proceed past intentionally unchecked reviewer-owned
checklists.

Use `blocked` only with a concrete recovery prompt. `/symphony status` reports current artifacts
and validation and then restores the same checkpoint. `/symphony cancel` removes the `symphony`
label and posts a cancellation comment. Never merge automatically, expose credentials, install the
official GitHub Spec Kit extension, or use `speckit-taskstoissues`.
