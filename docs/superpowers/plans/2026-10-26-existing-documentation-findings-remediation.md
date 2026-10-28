# Existing Documentation Findings Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This is required corrective work accompanying the [prevention plan](2026-10-26-agent-owned-documentation.md), not an optional backlog. Implementation is authorized and underway; the delivery record below tracks actual evidence separately from the original task checklist.


## Delivery record — 2026-10-28

The user authorized implementation, branch commits, pull requests, and merge. The original task
checklist below remains the design/acceptance record; it is not a claim that unchecked external
acceptance criteria passed. Implementation includes the command harness, generated facts, canonical
corrections, repository templates, managed-review provenance, runtime repairs, candidate release
smoke, and trusted scheduled external audits. The constitution landed in separate reviewed [PR #35](https://github.com/rohanyupadhyay/symphony-plus/pull/35)
as governance requires. Focused repair domains were delegated and reviewed independently; they
share one implementation PR because supervision, queue authority, review handoff, and update drains
need integration validation together. No unrelated dependency upgrade is included.

[The maintenance guide](../../../elixir/docs/documentation-maintenance.md) is the current per-finding
closure/evidence record. Local full-gate evidence currently covers 537 tests, zero failures, six
opt-in live tests skipped, 100% measured coverage, and clean lint/type analysis. Final review found no remaining Important/Critical blockers. Active ruleset 26013439 requires
`make-all` and `validate-pr-description`, with no bypass actors; a controlled failing check blocked
PR #35 before the valid body was restored. Implementation PR CI is recorded at delivery. Dedicated private
App/Codex and real SSH capabilities have not been established: those live acceptance boundaries
remain unavailable, not silently completed. A four-platform candidate release is checked by the
release workflow before publication; no new release is claimed by this implementation.

**Goal:** Correct the existing 37 audit findings and attach evidence to each resolution, while installing the checks that prevent recurrence.

**Architecture:** Deliver immediate factual/operator corrections first, then focused runtime repairs with regression tests, then external verification and presentation cleanup. Share the prevention plan's subprocess harness and required gate; do not bundle unrelated runtime changes into one large documentation PR.

**Tech Stack:** Existing Elixir 1.19.5/OTP 28, ExUnit, GitHub App integration, Bash, and GitHub Actions.

**Spec:** [Documentation correctness design](../specs/2026-10-26-agent-owned-documentation-design.md), especially FR-09, FR-10, and FR-13; [research/audit mapping](../research/2026-10-26-agent-owned-documentation-research.md). Existing product/feature specifications remain authoritative for runtime behavior.

## Global constraints

- Agents own every investigation, correction, regression test, review, and verification result. Missing administrative/fixture capabilities are explicit blockers, not routine manual documentation tasks.
- Preserve existing spec/plan/implementation approvals and repository merge policy. The policy amendment is a separate prevention task.
- Use the original finding IDs 1–37. Reuse existing evidence where source is unchanged; reproduce static/conditional findings before changing behavior and record any finding disproved by new evidence.
- A README warning is an immediate mitigation, not closure of a confirmed implementation defect. Do not weaken approved requirements to match bugs.
- Do not claim external verification passed when credentials/resources are unavailable. Never use production issues or interrupt an installed production service during tests.
- Each code repair must have a failing behavioral regression test, the smallest coherent fix, targeted verification, the full quality gate, and updated operator guidance in the same reviewed change.
- Share files/test helpers with the prevention plan; one task owns each implementation. Completion of shared harness work is credited to both plans rather than implemented twice.

## Review focus

1. Wrong project/data root/port can execute unrelated work; Task 2 uses the real CLI and separate temporary installations.
2. Repairing startup supervision can create duplicate queue/updater owners; Task 3 proves ownership and all-project quiescence.
3. Cancellation/review handling can mutate suspended work; Task 4 checks every applicable checkpoint and retains explicit human-change-request restrictions.
4. Update/SSH/quota recovery can silently change executable, worker, or thread identity; Tasks 5–6 prove the preserved identities and failure paths.
5. Textual corrections can conceal unfixed code or absent external evidence; the closure matrix and Task 9 prevent that completion claim.

## Delivery order

1. Task 1 confirms scope; Task 2 immediately corrects dangerous/incorrect instructions using the minimal shared process harness.
2. Prevention Tasks 1–6 run alongside the corrective work as dependencies permit. New regressions should be gated as soon as their tests pass.
3. Tasks 3–7 deliver focused runtime repairs. Task 5 depends on Task 3; Task 6's independent quota fixes can proceed separately. Keep sequential ownership where source files overlap.
4. Task 8 verifies private onboarding and corrects presentation; Task 9 closes the full audit with evidence.

The prevention milestone can ship before every runtime repair, but the overall documentation-correction effort is not complete until every finding is resolved or explicitly disproved with evidence. Blocked external findings remain open.

## Task 1: Establish the corrective acceptance baseline

**Files:** create `elixir/docs/documentation-maintenance.md` as the shared status/evidence guide specified by prevention Task 3. Read the source/specification files referenced by the research. Do not create a second claim database.

- [ ] Record the current source revision and retain all original IDs/titles in the matrix below. Use existing reproductions for unchanged code; prioritize fresh reproductions for source-only and conditional findings.
- [ ] For each finding distinguish factual text error, approved behavior violated by implementation, missing external evidence, or editorial drift. Confirm whether the source/spec actually supports the proposed correction.
- [ ] Assign its corrective task, intended observable outcome, and initial status `open`. Any rejected finding needs a concrete counterexample/source, not deletion.
- [ ] Use statuses `open`, `mitigated`, `blocked`, `resolved`, and `disproved`. Only resolved/disproved counts as closed. A mitigated implementation defect retains its repair/test requirement.
- [ ] Keep the guide concise and link tests/CI artifacts rather than copying raw logs. The closure matrix is the delivery checklist, not evidence by itself.

## Task 2: Correct existing launch, configuration, and safety guidance

**Files:** [root README](../../../README.md), [Elixir README](../../../elixir/README.md), [operator README](../../../.symphony-plus/README.md), [AGENTS.md](../../../elixir/AGENTS.md), [installation runbook](../../../elixir/docs/agent-installation.md), [reusable workflow](../../../elixir/examples/github-speckit-WORKFLOW.md), shared documentation examples tests/support from prevention Task 2.

- [ ] Bring forward the minimal exact-command subprocess harness from prevention Task 2. It does not depend on completing generated reference work or host-review provenance.
- [ ] Demonstrate the missing-acknowledgement failure, then correct every generic/source/binary launch example. Use explicit target workflow or clearly documented empty-registry startup, explicit service port, isolated data root, and matching CLI service-url/data-root options.
- [ ] Reconcile instructions for copied target workflows with the command actually launched; remove project-specific Linear/upstream-clone assumptions from generic onboarding. State authenticated tracker/Codex prerequisites before dispatch.
- [ ] Execute the corrected startup/registration/restart/list/remove sequence against a temporary memory-tracker installation. Assert the intended canonical workflow identity, bound endpoint, persistent registry, and isolation between two instances.
- [ ] Correct factual configuration and eligibility descriptions: configured terminal states, automatic-approval exceptions, required provider state lists, Jira ID-refresh scope, Asana incomplete/named-section eligibility, and the separate stall watchdog.
- [ ] Correct runtime prerequisites and testing examples: Bash, physical Codex auth-file requirement for live tests, working-directory convention, correct Plus spec link, and version/artifact examples.
- [ ] Make merge policy consistent: prohibit direct agent merging while describing the intended guarded host queue accurately. Preserve existing product approval gates. Replace repository-specific Elixir validation commands in the reusable template with explicit target customization requirements.
- [ ] Describe hook environment inheritance and the trusted-host execution boundary precisely. Do not claim that Codex-child scrubbing also scrubs earlier repository hooks.
- [ ] Add explicit temporary limitations for unresolved runtime findings. The implementation findings remain open/mitigated until their later tasks pass.
- [ ] Run the shared subprocess scenarios, applicable CLI/config/adapter tests, local-link checks, and independent review of the updated instructions. Record exact corrected sections and tested revision.

## Task 3: Repair registry ownership and safe reload

**Files:** [Application](../../../elixir/lib/symphony_plus.ex), [ProjectRuntime](../../../elixir/lib/symphony_plus/project_runtime.ex), [ProjectRuntimeSupervisor](../../../elixir/lib/symphony_plus/project_runtime_supervisor.ex), [WorkflowStore](../../../elixir/lib/symphony_plus/workflow_store.ex), [UpdateManager](../../../elixir/lib/symphony_plus/update_manager.ex), [MergeQueue](../../../elixir/lib/symphony_plus/github/merge_queue.ex), relevant runtime/update/queue tests.

- [ ] Specify the ownership change before coding: the installation updater must account for all managed projects; queue ownership must preserve repository/target serialization. Do not start one independent installation updater for every project.
- [ ] Write failing tests through normal documented CLI startup proving enabled update/queue services actually perform their work, without a legacy application-level workflow setting. Cover two projects, repeated registration, restart, and conflicting update policy.
- [ ] Implement one clear lifecycle owner per authority and prevent cross-project configuration leakage. Activation must wait for all applicable running/retry/quota/continuation/queue activity.
- [ ] Separately write failing reload tests: invalid YAML keeps the last good policy and admitted work; valid prompt/policy updates do not kill active agents unexpectedly; incompatible tracker/workspace changes have explicit safe transition behavior.
- [ ] Implement minimal reload repair consistent with [SPEC.md](../../../SPEC.md), preserving admitted work and applying validated policy at defined boundaries. Verify reload failure/recovery and service restart together.
- [ ] Run targeted project/runtime/update/queue tests and the full gate. Promote these scenarios to required coverage and remove only the corresponding temporary limitations.

Ownership and reload can be separate reviewed PRs inside this task. Their interfaces must be reconciled before combining them.

## Task 4: Repair managed-review commands and external PR lifecycle

**Files:** [WorkflowControl](../../../elixir/lib/symphony_plus/github/workflow_control.ex), [GitHub client](../../../elixir/lib/symphony_plus/github/client.ex), [AgentTool](../../../elixir/lib/symphony_plus/github/agent_tool.ex), [queue backend](../../../elixir/lib/symphony_plus/github/merge_queue/backend.ex), workflow-control/merge-queue tests, affected operator guides/templates.

- [ ] Define an explicit command/state matrix for status, cancel, revise, and retry across managed-review, queued, validating, blocked, and completed states. Preserve approved suspension restrictions and avoid authorizing unrelated branch mutations.
- [ ] Reproduce ignored commands with authorized comments, then test that status preserves the checkpoint, cancel prevents further execution/merge, and revision routes to its intended phase rather than automatic review.
- [ ] Reproduce externally closed/merged managed PRs becoming nondispatchable without reconciliation. Test correct parent-issue outcome for merged versus closed-unmerged PRs, including restart and repeated polls.
- [ ] Implement the required trigger/reconciliation changes without competing agent and host mutations. Re-read authority/head/eligibility before mutation.
- [ ] Run targeted workflow-control/queue tests and full gate; update the command matrix and PR lifecycle instructions to match. Close the findings only when behavior and instructions agree.

## Task 5: Repair automatic-update executable activation

**Dependency:** Task 3's installation-wide updater ownership. **Files:** [SourceUpdate](../../../elixir/lib/symphony_plus/source_update.ex), [apply-source-update](../../../elixir/scripts/apply-source-update), [run-github](../../../elixir/scripts/run-github), [bundled workflow](../../../elixir/WORKFLOW.md), existing source-update tests and operator guides.

- [ ] Use a disposable local Git remote and two distinguishable executable revisions. Reproduce that the candidate build is not installed and that the sample launcher resolves from the wrong directory.
- [ ] Define the activation contract: prepared executable promotion, retained workflow/profile/port/data-root/log options, clean fast-forward checkout, all-project quiescence, and a usable prior launch if activation fails.
- [ ] Write failing integration tests proving the newly prepared executable actually becomes the responding service. Test launcher failure, missing candidate executable, stale candidate, and interrupted handoff without touching production services.
- [ ] Fix executable installation and launcher working-directory/argument handling, including supported rollback behavior. Update the example and supervision instructions in the same change.
- [ ] Run source-update/script/public-startup tests and full gate. Close the finding with observed new revision and retained launch context, not a successful Git fast-forward alone.

## Task 6: Repair quota path, worker, concurrency, and cleanup contracts

**Files:** [Orchestrator](../../../elixir/lib/symphony_plus/orchestrator.ex), [AgentRunner](../../../elixir/lib/symphony_plus/agent_runner.ex), [QuotaWaitStore](../../../elixir/lib/symphony_plus/quota_wait_store.ex), [Config](../../../elixir/lib/symphony_plus/config.ex), quota/native-resume tests and guide.

- [ ] Add separate failing scenarios for launch cwd differing from workflow directory, SSH-host persistence across restart, tracker-state/worker-host capacity exhaustion, and terminal/cancelled quota-wait cleanup.
- [ ] Use one canonical root calculation for workspace creation, durable records, and existing-workspace validation. Preserve the original SSH worker identity; define safe legacy-record handling without guessing a different host.
- [ ] Apply the same applicable concurrency gates to quota resumes as ordinary dispatch. Reconcile terminal/cancelled/label-ineligible waits before resume and clean up according to the established workspace policy.
- [ ] Preserve the same native thread; unavailable context remains operator-blocking rather than starting fresh. Test repeated polls, resume reservation/restart, and failure paths using controlled protocol/SSH fixtures.
- [ ] Run targeted quota/app-server/workspace tests plus full gate. Record any real SSH/provider verification still unavailable; do not label fixture evidence as a live quota-renewal test.

## Task 7: Repair observability and promised review audit trails

**Files:** [Presenter](../../../elixir/lib/symphony_plus_web/presenter.ex), [observability controller](../../../elixir/lib/symphony_plus_web/controllers/observability_api_controller.ex), [ProjectRuntimeSupervisor](../../../elixir/lib/symphony_plus/project_runtime_supervisor.ex), [WorkflowControl](../../../elixir/lib/symphony_plus/github/workflow_control.ex), [AgentTool](../../../elixir/lib/symphony_plus/github/agent_tool.ex), [queue backend](../../../elixir/lib/symphony_plus/github/merge_queue/backend.ex), relevant tests/guides.

- [ ] Reproduce refresh returning unavailable in registry mode. Test the documented endpoint against active projects and explicit unavailable-project behavior; implement refresh of the intended managed schedulers.
- [ ] Correct terminal-status guidance immediately in Task 2. Restore normal terminal observability here only if the approved product contract requires it; otherwise the factual correction closes finding 10 without inventing new behavior.
- [ ] Test that host merge completion preserves the promised complete phase report and validation context from trusted workflow evidence. Produce the final report without fabricating phase counts or requiring a post-closure agent turn.
- [ ] Qualify legacy cursor documentation accurately. If current managed review requires equivalent cursor deduplication, implement/test it; otherwise prove current-head processing remains idempotent and remove the unsupported universal cursor claim. Preserve the normative idempotency requirement.
- [ ] Run API/observability/workflow/queue tests and full gate; verify comments and JSON through observable outputs rather than only rendering helpers.

## Task 8: Verify private onboarding and finish presentation corrections

**Files:** [AppProfile](../../../elixir/lib/symphony_plus/github/app_profile.ex), [App CLI](../../../elixir/lib/symphony_plus/github/app_cli.ex), [GitHub Auth](../../../elixir/lib/symphony_plus/github/auth.ex), [Workspace](../../../elixir/lib/symphony_plus/workspace.ex), onboarding guides/templates, App/launcher tests, current screenshot asset if replaced.

- [ ] Correct the registration permission request and runbook for private-repository check/status access. Extend verification or narrow its documented guarantee so repository visibility is not presented as complete permissions validation.
- [ ] Select and implement a complete authenticated private-clone bootstrap, or document and verify an already-supported host Git authentication arrangement. App API/push credentials alone must not be assumed to authenticate plain HTTPS clone. Keep short-lived credentials out of tracked files, origin URLs, logs, and Codex environments.
- [ ] Test permission failures and credential-safe clone behavior with local HTTP/Git fixtures. Then verify the documented path against a dedicated authorized private repository; absence of that capability leaves findings 12/17 blocked rather than resolved.
- [ ] Replace the stale screenshot with observed current UI output, or label it explicitly historical. Reorganize the product introduction, update the upstream attribution, and label Linear-specific onboarding. Do not use an invented mockup as evidence of the running UI.
- [ ] Run focused App/launcher/onboarding tests, links and artifact-name checks, full gate for code changes, and independent reader review. Record the actual external capability/ref tested without secret values.

## Task 9: Close the audit with evidence and regression protection

- [ ] Review all 37 matrix rows against their observable closure criteria. Require test/CI evidence for implementation repairs and reader/source verification for factual/editorial corrections.
- [ ] Promote passing repaired behavior scenarios into the required prevention gate. Remove temporary limitations only when the corresponding repair is verified.
- [ ] Perform a fresh operator journey from corrected instructions and a documentation/implementation consistency review by an independent agent context.
- [ ] Report resolved/disproved counts separately from mitigated/blocked/open. Do not declare the corrective effort complete with blocked external checks or unresolved confirmed runtime findings.

## Complete finding-to-correction matrix

The matrix preserves the original acceptance criteria. Current statuses and test links are maintained
in the [maintenance guide](../../../elixir/docs/documentation-maintenance.md).

| ID | Finding | Task | Closure criterion |
|---|---|---|---|
| 1 | Missing acknowledgement | 2 | Every launch example works or intentionally demonstrates rejection; real-command test passes. |
| 2 | Wrong/customized workflow mismatch | 2 | Published journey registers the intended target, with correct setup prerequisites and clone assumptions. |
| 3 | Stale no-path/missing-workflow semantics | 2 | Guide distinguishes empty registry, restored unavailable registrations, and failed explicit registration. |
| 4 | Dashboard/default-port mismatch | 2 | Published command yields the stated endpoint; service/project port semantics are accurate. |
| 5 | Two services share registry | 2 | Explicit separate data roots and two-instance test show no registration sharing. |
| 6 | CLI targets another installation | 2 | Cross-cwd list/add/remove reach the documented data root/service URL. |
| 7 | Update/queue owners absent | 3 | Normal registry startup performs enabled update/queue work with correct ownership. |
| 8 | Reload stops admitted work | 3 | Invalid reload retains last good policy; valid reload follows the approved safe transition contract. |
| 9 | Update handoff fails/stale executable | 5 | Prepared executable becomes the service with retained context; failure recovery works. |
| 10 | Terminal status claim | 2/7 | Documentation identifies supported normal surfaces, or restored terminal behavior is verified. |
| 11 | Registry refresh unavailable | 7 | Public refresh endpoint operates on intended project schedulers with tested failure semantics. |
| 12 | App permission/verification gaps | 8 | Correct permissions and honest verification scope pass dedicated private-repository checks. |
| 13 | Conflicting merge policy | 2 | Guides/templates consistently describe guarded host merge and preserve explicit approvals. |
| 14 | Managed-review commands ignored | 4 | Authorized commands perform their defined action in every applicable state. |
| 15 | External PR closure/merge stranded | 4 | Parent lifecycle reconciles idempotently after external outcomes and restart. |
| 16 | Repository-specific reusable validators | 2 | Template clearly requires target-specific validation and no accidental Symphony Plus-only commands remain. |
| 17 | Private clone auth missing | 8 | Documented bootstrap clones a dedicated private repository without leaked credentials. |
| 18 | Hook credential boundary unclear | 2 | Guide explicitly describes host-hook inheritance and Codex-child scrubbing scope. |
| 19 | Final phase report absent | 7 | Observed host completion contains the promised trusted phase/validation report. |
| 20 | Cursor claim describes legacy state | 7 | Scope is accurate and current managed-review idempotency is demonstrated. |
| 21 | Fixed terminal-state wording | 2 | Guide refers to configured states and labels provider-specific defaults accurately. |
| 22 | Approval behavior overstated | 2 | Auto-approval versus operator blocking is explained for configured policies. |
| 23 | Mandatory provider states omitted | 2 | Complete Asana/GitLab examples validate with explicit required lists. |
| 24 | Jira refresh scope inaccurate | 2 | Candidate/status filtering and ID/project refresh behavior are distinguished. |
| 25 | Asana eligibility omitted | 2 | Named-section and incomplete-task conditions are explicit and match adapter behavior. |
| 26 | Stall watchdog omitted | 2 | Both timeout controls, defaults, and disable semantics are documented accurately. |
| 27 | Relative quota roots differ | 6 | Creation, persistence, and resume find the same root across cwd/workflow-directory differences. |
| 28 | SSH quota worker lost | 6 | Restart resumes on the original worker or explicitly blocks; no silent local fallback. |
| 29 | Resume bypasses capacity gates | 6 | Global, tracker-state, and worker-host bounds hold during due resumes. |
| 30 | Terminal quota wait cleanup missing | 6 | Terminal/cancelled waits release state and clean workspaces under the approved policy. |
| 31 | Bash prerequisite missing | 2 | Source/binary prerequisites identify Bash for local worker execution. |
| 32 | Testing cwd instructions conflict | 2 | Every test snippet runs from its stated directory. |
| 33 | Live-test auth-file prerequisite missing | 2 | Required physical auth file is explicit for every affected test path. |
| 34 | Wrong specification link | 2 | Custom implementation instructions point to the maintained Plus contract. |
| 35 | Stale binary version | 2 | Example naming matches the intended release/version policy and actual artifact pattern. |
| 36 | Historical screenshot unlabelled | 8 | Screenshot shows observed current UI or is clearly historical. |
| 37 | Introduction/provider organization | 8 | Product introduction leads; feature grouping, attribution, and provider labels are accurate. |

## Completion evidence

Each resolved row records changed documentation/source, passing scenario or source/reader verification, tested revision, relevant CI/artifact link, and independent review. A disproved row records contrary evidence. Until then it remains open, mitigated, or blocked.

The full delivery consists of this corrective plan plus the [prevention plan](2026-10-26-agent-owned-documentation.md). Neither “all findings mapped” nor “new documentation checks are green” means that the existing defects are fixed.
