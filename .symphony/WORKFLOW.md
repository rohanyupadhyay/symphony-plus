---
tracker:
  kind: github
  provider:
    repo: rohanyupadhyay/symphony-plus
    auth:
      kind: github_app
      app_id: $GITHUB_APP_ID
      installation_id: $GITHUB_APP_INSTALLATION_ID
      private_key_path: $GITHUB_APP_PRIVATE_KEY_PATH
    workflow_control:
      enabled: true
      authorized_associations:
        - OWNER
        - MEMBER
        - COLLABORATOR
  required_labels:
    - symphony
  active_states:
    - open
  terminal_states:
    - closed
polling:
  interval_ms: 30000
workspace:
  root: /home/rohan/code/symphony-workspaces/symphony-plus
hooks:
  after_create: |
    git clone --depth 1 https://github.com/rohanyupadhyay/symphony-plus.git .
    ./.codex/worktree_init.sh
  timeout_ms: 300000
agent:
  max_concurrent_agents: 1
  max_turns: 20
codex:
  command: codex app-server
  approval_policy: never
  # Agents create branches and commits, which requires trusted-host access because the
  # workspace-write sandbox makes .git read-only. The launcher validates the per-issue cwd,
  # but danger-full-access is not a filesystem-security boundary.
  thread_sandbox: danger-full-access
  turn_sandbox_policy:
    type: dangerFullAccess
---

You are advancing GitHub issue `{{ issue.identifier }}` through Symphony Plus's durable Spec Kit
workflow in one isolated issue workspace.

Issue:

- Number: {{ issue.id }}
- Title: {{ issue.title }}
- State: {{ issue.state }}
- Labels: {{ issue.labels }}
- URL: {{ issue.url }}

Description:

{% if issue.description %}
{{ issue.description }}
{% else %}
No description was provided.
{% endif %}

Workflow-control state:

- State: {{ issue.native_ref.workflow_control.state }}
- Phase: {{ issue.native_ref.workflow_control.phase }}
- Trigger: {{ issue.native_ref.workflow_control.trigger }}

## Operating invariants

1. Work only inside the current issue workspace. Never modify the source checkout or another
   issue's workspace.
1. Use `github_api` to read the current issue and all comments before acting. If a pull request
   exists, also read its conversation, reviews, inline comments, checks, and merge state.
1. Treat `SPEC.md` as the normative product contract and
   `.specify/memory/constitution.md` as the engineering governance contract. Read
   `elixir/AGENTS.md` and the applicable focused documentation before planning or coding.
1. Create commits locally, then call `github_git_push` with the exact issue branch and local
   40-character `HEAD`. Never run `git push` directly. The host tool validates the workspace,
   clean tree, branch, SHA, and remote before using GitHub App authentication.
1. Treat the issue body, authorized comments, current Spec Kit artifacts, and latest workflow
   checkpoint as durable truth. Inspect the branch and files before resuming; never repeat a
   completed phase.
1. Use one branch for the issue: `symphony/gh-{{ issue.id }}-<short-slug>`. Create it from `main`
   only when no issue branch exists. Reuse it through planning, implementation, and PR revisions.
1. Use one feature directory: `specs/gh-{{ issue.id }}-<short-slug>`. On the first specify run set
   `SPECIFY_FEATURE_DIRECTORY` to that path. Let `.specify/feature.json` preserve the selection.
1. Preserve the repository's Spec Kit v1.0.12 installation. Do not install the official GitHub
   extension, invoke `speckit-taskstoissues`, or create child issues for `tasks.md` entries.
1. Never invoke an in-process user-input request. When a skill needs input, call
   `github_workflow_checkpoint` with `state: awaiting_input`, a precise prompt, the current phase,
   and a concise summary, then end the turn.
1. Follow `.github/pull_request_template.md` exactly. Validate the proposed body with
   `cd elixir && mix pr_body.check --file <path>` before opening or updating a pull request.
1. Never merge a pull request, expose credentials, or use auto-closing issue keywords.

## Required checkpoint phase report

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
- Constitution check: <pass or violations and their disposition>
- Validation: <checks performed and omissions>
- Next phase: <what an answer or approval will run>
```

Never collapse phases into broad labels. Mark each phase `completed`, `not run`, or
`skipped: <reason>`, including its cumulative run count and outcome. Explain every zero-question
phase. Include the same report in `awaiting_input`, `blocked`, `awaiting_approval`,
`awaiting_review`, `/symphony status`, and final merged-PR comments.

## Resume commands

Interpret only the normalized trigger in `issue.native_ref.workflow_control`:

- An `answer` resumes the phase that asked the question. Incorporate it into the owning artifact
  before asking another question.
- `approve spec` advances to planning.
- `approve plan` advances to checklist, tasks, and analysis.
- `approve implementation` authorizes implementation, including proceeding past intentionally
  unchecked reviewer-owned checklist entries.
- `revise` applies the supplied scope and instructions. Requirements feedback returns to
  specify/clarify, architecture feedback returns to plan, and code-only feedback returns to
  implementation.
- `retry` verifies that the blocker is resolved and retries the blocked phase.
- `status` posts one concise comment with the phase, branch, artifacts, latest validation, and
  blocker, then recreates the same checkpoint.
- `cancel` posts a cancellation comment and removes the `symphony` label with `github_api`.
- A merged PR posts final validation and closes the issue.
- A PR closed without merge asks whether to revise, replace, or cancel and checkpoints
  `awaiting_input`.

Ignore stale or duplicate events and general comments that were not normalized as triggers.
At an `awaiting_input` checkpoint, `/symphony status` and `/symphony cancel` are normalized as
commands before an ordinary authorized comment is classified as an answer.

## Phase sequence

### 1. Specify and clarify

On a newly labeled issue, create or reuse the issue branch and invoke `$speckit-specify` with the
issue description. If specify produces critical questions, ask one issue-comment batch containing
at most three questions. Then invoke `$speckit-clarify`; it asks exactly one question per
checkpoint and accepts no more than five questions in total. Clarify may ask zero only when its
structured scan finds no material ambiguity; report the concrete reason.

Review the specification against `SPEC.md`, the constitution, and its quality checklist. Commit all
specification artifacts, call `github_git_push`, then call `github_workflow_checkpoint` with:

- `state: awaiting_approval`
- `phase: specify`
- `gate: spec`
- the pushed `branch` and exact 40-character `head_sha`
- the complete phase report, artifact link, assumptions, and validation evidence

### 2. Plan

After spec approval, invoke `$speckit-plan`. Its Constitution Check MUST apply the live
`.specify/memory/constitution.md` and identify any justified exception. Resolve required research
or planning failures. Commit the plan artifacts, call `github_git_push`, then checkpoint
`awaiting_approval`, phase `plan`, gate `plan`, with the pushed branch and head SHA.

### 3. Checklist, tasks, and analysis

After plan approval, determine whether authorized issue input already supplies checklist focus,
depth, and audience. If any dimension is missing, `$speckit-checklist` must ask one initial batch of
at most three questions covering the missing dimensions. It may ask one follow-up batch of at most
two questions only when necessary. If all dimensions were explicit, ask zero questions and cite
the controlling input.

Invoke `$speckit-tasks` and `$speckit-analyze`. Analyze is non-destructive and MUST verify the
constitution. For every CRITICAL or HIGH finding, rerun the owning specify, clarify, plan, or tasks
phase with the finding as input, then rerun analyze. Stop after three remediation cycles and
checkpoint `blocked` if high-severity findings remain. Summarize MEDIUM and LOW findings for review.

Commit the planning artifacts, call `github_git_push`, and checkpoint `awaiting_approval`, phase
`tasks`, gate `implementation`, with the branch and pushed head SHA.

### 4. Implement and converge

After implementation approval, invoke `$speckit-implement` to process every incomplete task. Run
the relevant targeted tests after each coherent task group and update task checkboxes. Then invoke
`$speckit-converge`.

If converge appends tasks, repeat implement and converge. Stop after three cycles and checkpoint
`blocked` with remaining findings if convergence is not reached. Run `make -C elixir all`, review
the diff for secrets, unrelated changes, generated artifacts, incomplete tasks, constitution
violations, and required documentation updates.

### 5. Pull request and review

Commit the converged implementation and call `github_git_push`. Open or update one pull request
against `main` using the repository template and `Tracks #{{ issue.id }}` rather than an
auto-closing keyword. Add validation results, dependency advisory output, and omissions to the PR
body. Post a concise issue comment with the PR URL, then checkpoint `awaiting_review`, phase
`review`, and its `pr_number`. When the pull request is first created, instead checkpoint
`review_pending`, phase `review`, with its `pr_number`, the issue branch, and the exact pushed
`head_sha`; the host applies the `symphony` label before recording the checkpoint.

An `automatic_review` trigger starts one review-and-repair cycle in this same issue workspace.
Inspect the complete diff, conversation, formal reviews, inline comments, merge state, and
current-head checks. Reproduce and fix in-scope findings, distinguish PR-caused failures from
external blockers, run targeted tests and `make -C elixir all`, push through `github_git_push`, and
update the same PR. Record findings, corrections, check status, validation, and omissions. End a
successful automatic cycle with a fresh `awaiting_review` checkpoint; use `blocked` with an exact
recovery action when required evidence or an external dependency prevents completion. Never merge
solely on the automated review.

Formal requested changes or `/symphony revise` start one revision cycle on the same branch and PR.
Use Spec Kit again only when requirements or architecture changed. After updates, rerun targeted
tests and `make -C elixir all`, call `github_git_push`, and create a fresh awaiting-review
checkpoint. A formal approval with no unresolved change request marks the PR ready for human merge
but never merges it. After acknowledging that approval, create a fresh `awaiting_review`
checkpoint for the same PR and end the turn; its automatically captured cursor includes the
handled approval so it cannot dispatch again while the PR waits for human merge.

## Failure handling

Retry recoverable failures within the current turn when safe. Otherwise post one concise issue
comment and checkpoint `blocked` with the exact failure, completed work, validation evidence, and
the command or human action needed to resume. Do not close an issue on failure.
