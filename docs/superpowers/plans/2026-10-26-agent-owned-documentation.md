# Agent-Owned Documentation Correctness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Implementation is authorized and underway. The dated delivery record below supersedes the original planning-time status statements.


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
remain unavailable, not silently completed. The [first post-merge nightly](https://github.com/rohanyupadhyay/symphony-plus/actions/runs/40639531701)
passed the actual candidate commands on all four supported platforms at source `7eb757b` before
nightly publication. No stable release tag was created.

**Goal:** Have agents maintain and demonstrate the correctness of operational documentation, with deterministic checks required before merge and independent agent review of narrative claims. Correcting the existing findings is required delivery work in the [companion remediation plan](2026-10-26-existing-documentation-findings-remediation.md).

**Architecture:** Reuse ExUnit to execute selected published shell commands through the development escript. Generate bounded reference facts from existing metadata. Connect constitution obligations, Spec Kit template overrides, agent workflow evidence, and the existing GitHub quality gate; add host-enforced review provenance and controlled external/release checks in separately scoped follow-ups.

**Tech Stack:** Elixir 1.19.5/OTP 28 via mise; existing Ecto/Jason/Req dependencies; Bash; GitHub Actions and repository rulesets; installed Spec Kit 1.0.12.

**Spec:** [Proposed design](../specs/2026-10-26-agent-owned-documentation-design.md). Read alongside [research and source references](../research/2026-10-26-agent-owned-documentation-research.md).

## Global constraints

- Agents own impact assessment, documentation changes, verification, and repair PR preparation. No recurring human README synchronization or review step.
- Preserve the normative [SPEC.md](../../../SPEC.md), product spec/plan/implementation approval checkpoints, required GitHub reviews, existing PR headings, and host merge policy.
- The combined constitution amendment changes the blanket human PR-review requirement and therefore proposes version **2.0.0**, not a minor bump. It is a dedicated future reviewed change, not part of this planning commit.
- Never edit installed Spec Kit skill files or integration manifests for this feature; use repository-owned template overrides and workflow instructions.
- Required PR checks use no production credentials, real Codex work, or production tracker resources. Never automatically execute arbitrary Markdown.
- Do not redefine approved behavior around known bugs, infer passing evidence from a skipped/unavailable run, or put expected-red diagnostics on PR heads.
- Keep the initial prevention implementation limited to Tasks 1–6. Task 7 is a separate host-review feature; Tasks 8–9 are follow-up release/integration work. Existing-finding corrections are mandatory companion work, delivered through the [remediation plan](2026-10-26-existing-documentation-findings-remediation.md), with focused runtime repair features rather than indefinite deferral.
- No new Python/Node toolchain, documentation site, validation-library migration, general claim registry, or evidence database is required.

## Review focus

1. **Wrong working directory or stale executable:** use the freshly built development escript, an external temporary cwd, and the actual target workflow; Task 3 tests these observations.
2. **Host environment leakage and orphan processes:** isolated HOME/XDG/Codex/data/log roots and process-group cleanup on failures; Task 2 tests sentinel credentials and timeout cleanup.
3. **Code changes without README changes:** required checks run unconditionally and compare generated facts plus observable behavior; Tasks 4 and 6 test drift and CI wiring.
4. **Stale or self-authored review evidence:** source-head provenance comes from host session metadata, not an author checkbox; Task 7 rejects same-thread and mismatched-source evidence.
5. **Absent external capability or baseline defect:** report unavailable/failed explicitly and retain the intended contract; Tasks 3 and 9 test/classify limitations rather than silently passing them.

## Milestones and completion boundaries

| Milestone | Tasks | What completion means |
|---|---|---|
| A: useful deterministic protection | 1–6 | Correct canonical startup, tested public commands, generated facts, agent obligations, and active required checks. Narrative review is an explicit agent workflow obligation; host provenance is not yet claimed. |
| B: enforced independent review | 7, after queue lifecycle repair R1 | Required-mode managed queue admission verifies host-stamped review provenance for the reviewed source head and integration lineage. |
| C: release and external evidence | 8–9 | Candidate binaries are checked before publication and trusted external canaries produce current pass/fail/unavailable evidence and repair routing. |
| R: existing findings corrected | Companion remediation Tasks 1–9, interleaved with A–C | All 37 findings are individually resolved or disproved with evidence; blocked/mitigated runtime findings do not count as closed. |

Milestone A is the recommended first prevention scope, alongside immediate corrections in remediation Task 2. It must not be reported as repairing all 37 audit findings or proving every narrative claim. The overall effort includes Milestone R; see its per-finding closure matrix. Each task should be an independently reviewable change; keep the constitution amendment separate as its governance requires. Use normal repository review/merge flow rather than committing automatically because this plan contains commit steps.

## File ownership map

| Area | Existing files to modify | Proposed files |
|---|---|---|
| Governance | [constitution](../../../.specify/memory/constitution.md) | None |
| Exact-command harness | [test helper](../../../elixir/test/test_helper.exs), [mix.exs](../../../elixir/mix.exs) test-support discovery | `elixir/test/support/documentation_support.exs`, `elixir/test/symphony_plus/documentation_support_test.exs`, `elixir/test/symphony_plus/documentation_examples_test.exs` |
| Canonical docs and debt | [root README](../../../README.md), [Elixir README](../../../elixir/README.md), [operator README](../../../.symphony-plus/README.md), [installation runbook](../../../elixir/docs/agent-installation.md), [workflow example](../../../elixir/examples/github-speckit-WORKFLOW.md) | `elixir/docs/documentation-maintenance.md` |
| Generated facts/checks | [CLI](../../../elixir/lib/symphony_plus/cli.ex), [schema](../../../elixir/lib/symphony_plus/config/schema.ex), [Makefile](../../../elixir/Makefile) | `elixir/lib/symphony_plus/documentation.ex`, `elixir/lib/mix/tasks/docs.generate.ex`, `elixir/lib/mix/tasks/docs.check.ex`, `elixir/docs/configuration-reference.md`, `elixir/test/symphony_plus/documentation_generation_test.exs` |
| Agent obligations | [AGENTS.md](../../../elixir/AGENTS.md), [self-hosting workflow](../../../.symphony-plus/WORKFLOW.md), [reusable workflow](../../../elixir/examples/github-speckit-WORKFLOW.md) | `.specify/templates/overrides/plan-template.md`, `.specify/templates/overrides/tasks-template.md` |
| Merge gate | [make-all workflow](../../../.github/workflows/make-all.yml), [Makefile](../../../elixir/Makefile); remote effective branch rules | No additional always-on docs workflow needed |
| Optional host provenance | [AppServer](../../../elixir/lib/symphony_plus/codex/app_server.ex), [AgentTool](../../../elixir/lib/symphony_plus/github/agent_tool.ex), [WorkflowControl](../../../elixir/lib/symphony_plus/github/workflow_control.ex), [queue state](../../../elixir/lib/symphony_plus/github/merge_queue/state.ex), [backend](../../../elixir/lib/symphony_plus/github/merge_queue/backend.ex) | `elixir/lib/symphony_plus/github/documentation_review.ex`, focused tests |
| Release/external checks | [Burrito workflow](../../../.github/workflows/burrito-release.yml), existing opt-in live tests | `.github/workflows/documentation-canary.yml`, `elixir/scripts/docs-release-smoke` |

Proposed filenames/interfaces are implementation decisions for this plan. They do not imply that these files or commands exist today.

## Task 1: Amend the constitution with an agent-owned, evidence-based obligation

**Files:** Modify [constitution.md](../../../.specify/memory/constitution.md). Consume the design FR-01, FR-07–FR-09; produce the approved governance obligation used by Tasks 3–7.

- [ ] Read the installed constitution skill and preserve its scope: amend the constitution only; dependent template and CI work belongs to later tasks.
- [ ] Add a principle requiring agents to identify affected documented claims, update canonical instructions, execute applicable examples, and provide fresh observable evidence. Prohibit weakening intended requirements merely to describe defects.
- [ ] Replace the blanket human PR-review requirement with independent agent technical review where repository policy permits. Preserve all explicit product checkpoints and GitHub-required reviews; do not equate agent-owned documentation with permission to remove them.
- [ ] State that unresolved affected contracts block that feature's completion; unrelated pre-existing debts remain visible with repair references rather than making every unrelated change impossible.
- [ ] Update version from 1.1.0 to 2.0.0 and amendment date at implementation time, preserve ratification date, and describe migration of existing work. Use the current date when executing, not this plan's date automatically.
- [ ] Validate the amendment against [SPEC.md](../../../SPEC.md), existing workflow gates, and governance. This is a documentation/policy change: use semantic independent review and `git diff --check`, not a test that merely searches for the new wording.
- [ ] Prepare the dedicated constitutional amendment for normal review, with the later enforcement tasks explicitly outstanding. Do not claim the amendment itself enforces CI.

## Task 2: Build a small, safe exact-command test harness

**Files:** Create the three documentation test/support files in the file map. Modify [test_helper.exs](../../../elixir/test/test_helper.exs) to load the helper and [mix.exs](../../../elixir/mix.exs) only if test-support discovery requires it. FR-03, FR-04, FR-12.

**Interfaces:** test-only `SymphonyPlus.DocumentationSupport.command_block!(path, id) :: binary()`; `with_service(command, fixture_options, assertion_fun) :: term()`. The fixed scenario map lives in the examples test, not in a general YAML claim registry.

- [ ] Write failing helper tests: `extracts_exact_marked_fence_bytes`, `rejects_missing_or_duplicate_ids`, `preserves_command_failure`, and `cleans_up_process_tree_after_timeout`. Assertions must establish actual exit/listener/process behavior rather than only PID existence.
- [ ] Run `mise exec -- mix test test/symphony_plus/documentation_support_test.exs`; expect failure because the helper is absent.
- [ ] Implement the single marker grammar `<!-- docs:scenario ID -->` immediately preceding a Bash fence. Reject malformed expected blocks. Do not add flags, rewrite paths, or execute unregistered fences.
- [ ] Implement temporary cwd/HOME/XDG/Codex/data/log/workspace roots, an explicit sanitized subprocess environment, bounded readiness, captured bounded output, and guaranteed OS process-tree cleanup. Keep mise/tool executables available through a deliberate PATH while excluding operator credentials and startup files. On Linux use a dedicated process group; Task 8 adds/validates equivalent macOS cleanup rather than pretending Linux behavior proves it.
- [ ] Supply fixture ports and paths only through variables stated in the documentation. Allocate a loopback port and retry a bounded three times on a proven bind collision; do not retry arbitrary application failures. Track each child independently for cleanup. Default deadlines: 15 seconds to readiness and 5 seconds for termination.
- [ ] Add a sentinel environment test showing a fake host token/config cannot be read by the fixture child, and a test showing an assertion failure also cleans up. Fixtures contain no real issues or user hooks.
- [ ] Re-run the helper test file and inspect its cleanup assertions. Prepare the focused change for review.

Representative helper assertion (use the fixture's exact bytes, including quoting/newlines):

```elixir
assert DocumentationSupport.command_block!(fixture_path, "service-start") == published_body
assert_raise ArgumentError, fn -> DocumentationSupport.command_block!(duplicate_fixture, "service-start") end
```

## Task 3: Correct canonical startup and prove the published operator journey

**Files:** Modify the READMEs/runbook/examples listed in the file map, [documentation_contract_test.exs](../../../elixir/test/symphony_plus/documentation_contract_test.exs), and [cli_test.exs](../../../elixir/test/symphony_plus/cli_test.exs). Create the maintenance guide and examples suite. FR-03–FR-05, FR-09, FR-10, FR-12.

**Consumes:** Task 2 helper. **Produces:** marked canonical commands, real CLI behavior tests, and a durable bounded debt table with the audit IDs summarized in the research.

- [ ] Write the first failing public-command test against the currently published launch instruction. Build with `mise exec -- mix build` in the development environment, then execute the extracted command against that executable. It must expose the missing acknowledgement rather than using injected CLI callbacks.
- [ ] Correct the root quick start: build/install context, explicit acknowledgement, explicit service port/data directory, and a clear choice between empty-registry startup and registering the actual customized target workflow. Explain authenticated Codex/tracker prerequisites before dispatch. The detailed guide owns provider-specific onboarding; do not duplicate competing generic commands.
- [ ] Mark and test these scenario IDs: `service-start`, `project-add`, `project-list`, `project-remove`. Define paths/port as documented operator inputs; all dependent blocks share the same fixture context. Keep installation/download commands separately classified as cold-install scenarios.
- [ ] Add observable assertions: zero projects at empty startup; correct target workflow/project identity after add; persistent canonical registration after restart; offline list from another cwd with the correct data root; add/remove targeting the explicit service URL; idle remove preserves workspace files. Assert the service remains healthy, not merely that `CLI.evaluate` returns `:ok`.
- [ ] Add two-instance isolation and invalid/repaired-registration tests using distinct absolute data roots and empty memory trackers. The latter proves unavailable-to-active recovery; it does not certify last-known-good live reload, which remains repair R2.
- [ ] Add an acknowledgement-denial subprocess test and mutation fixtures for wrong workflow selection and incorrect service/data-root addressing. Require useful file/scenario diagnostics on failure.
- [ ] Correct the remaining factual guidance from audit groups 10, 13, 16, 18, 21–26, 31–35; include Bash, physical auth-file requirements for live tests, configured tracker states, approval-policy exceptions, and the independent stall watchdog. Describe hooks as trusted host execution. Do not change actual external merge policy or runtime behavior in this task.
- [ ] Create the maintenance guide with the known-defect table: audit ID, intended contract/source, current limitation, reproducer, workaround, repair ID, and acceptance criterion. Replace unconditional claims for unavailable features with explicit implementation limitations while preserving normative specifications. Include editorial findings 36–37 as low-priority items; replace the screenshot only after the represented UI can be observed.
- [ ] Correct the misleading existing CLI test name/assertions. Run `mise exec -- mix test test/symphony_plus/documentation_examples_test.exs test/symphony_plus/cli_test.exs test/symphony_plus/documentation_contract_test.exs` after the development build; require all selected scenarios to pass and name the still-unverified runtime contracts in the handoff.

## Task 4: Generate authoritative facts and add non-writing documentation checks

**Files:** Create the documentation module, two Mix tasks, generated reference, and generation test in the file map. Modify [CLI](../../../elixir/lib/symphony_plus/cli.ex) to expose shared option metadata and READMEs to link to the reference. FR-06, FR-12.

**Interfaces:** `SymphonyPlus.Documentation.render_reference(repo_root) :: {:ok, binary()} | {:error, term()}`; `check(repo_root) :: :ok | {:error, [map()]}`. `mix docs.generate` writes only designated generated output; `mix docs.check` writes nothing and exits nonzero for stale facts/broken scoped local references/invalid designated example configuration.

- [ ] Write failing tests: deterministic render across environments, stale-reference rejection without mutation, missing-local-reference rejection, accepted required-provider examples, and absence of sentinel credentials/absolute host paths from generated output.
- [ ] Run `mise exec -- mix test test/symphony_plus/documentation_generation_test.exs`; expect failure for the missing module/tasks.
- [ ] Expose `CLI.service_switches/0` and `CLI.project_switches/1` from the parser's actual declarations, and route parsing through those same declarations. Include specs for new public functions. Do not maintain a second documentation-only flag list.
- [ ] Render only selected declared schema types/defaults, service/project flags, versions from mise/project metadata, and release targets. Do not call `Config.settings!`, resolve environment secrets, load App profiles, or treat context-dependent defaults as universal effective values. Keep explanatory lifecycle prose outside generated output.
- [ ] Implement the two Mix tasks and scope local-link/configuration checking to maintained operator docs and executable examples. Template placeholders are explicit fixtures, not accidental invalid-production configurations. Live URLs are not a deterministic PR dependency.
- [ ] Generate the reference, link canonical guides to it, and prove that running generation twice gives identical bytes and `docs.check` leaves the worktree unchanged. Mutation fixtures must fail when facts or CLI declarations drift.
- [ ] Run the generation tests, `mise exec -- mix docs.check`, `mise exec -- mix specs.check`, and relevant CLI tests. Prepare the focused change with the generated output reviewed alongside its source metadata.

Representative non-writing drift assertion:

```elixir
before = File.read!(reference_path)
assert {:error, findings} = Documentation.check(stale_fixture_root)
assert Enum.any?(findings, &(&1.code == :stale_generated_reference))
assert File.read!(reference_path) == before
```

## Task 5: Make agent planning, convergence, and review account for documentation

**Files:** Create the plan/tasks template overrides. Modify [AGENTS.md](../../../elixir/AGENTS.md), [self-hosting workflow](../../../.symphony-plus/WORKFLOW.md), [reusable workflow](../../../elixir/examples/github-speckit-WORKFLOW.md), and the maintenance guide. FR-01, FR-02, FR-07, FR-09.

- [ ] Resolve the current templates with `.specify/scripts/bash/resolve-template.sh plan-template --json` and the equivalent tasks command. Preserve existing mandatory structure in the overrides, add only repository-specific obligations, and record upstream Spec Kit version 1.0.12 for future upgrade review.
- [ ] Require a short feature-plan table: changed operator behavior, canonical document/section, scenario or generated reference, and evidence boundary. A no-impact statement needs a concrete reason; it does not require touching the README unnecessarily.
- [ ] Replace optional-testing guidance in the project task override for affected operational contracts with explicit verification tasks and acceptance outcomes. Cover code changes with unchanged documentation as well as documentation-only changes.
- [ ] Require agents to perform exact-command checks, preserve normative intent, update known limitations, and link actual current CI evidence under existing PR/checkpoint sections. Preserve PR headings exactly; the PR-body checker proves formatting, not truth.
- [ ] Add independent reader-oriented documentation review to the existing automatic-review instructions. A fresh invocation reviews the actual changed code/docs rather than only the author's summary. Record source head, claims checked, observations, unresolved findings, and external omissions. Corrections require another review of the resulting source head.
- [ ] Keep analyze/converge within their installed scope: declared documentation tasks are part of feature intent; converge appends missing work and does not become a git/diff auditor. Avoid extension hooks as the only mandatory enforcement mechanism.
- [ ] Validate template resolution and conduct an isolated agent dry run for two small fixture changes: a service-default change and a purely internal refactor. The first must produce documentation/test work; the second must give a justified no-impact outcome. Independently review resulting artifacts rather than adding substring tests for policy prose.

## Task 6: Enforce the documentation quality gate locally and in GitHub

**Files:** Modify [Makefile](../../../elixir/Makefile) and [make-all.yml](../../../.github/workflows/make-all.yml). Configure effective remote rules only during this implementation task, after preparing/reviewing the concrete settings. FR-08, FR-12.

- [ ] Add `docs-check` to the Makefile: build the development escript, run the non-writing `mix docs.check`, and execute tests tagged `:documentation`. Make direct test/coverage targets build the development executable as a prerequisite when they include process scenarios.
- [ ] Add `mix docs.check` to `make all` after build and run command tests once through existing coverage. Keep one unconditional `make-all` CI check; avoid a second job rerunning the same process scenarios. No paths filter, credential condition, `continue-on-error`, or skipped required sub-gate.
- [ ] Run the complete gate with the normal cache and once from a clean checkout with fresh Mix home/build/deps. The audit already demonstrated automatic Hex/Rebar setup on the pinned runtime; add bootstrap commands only if this cold run proves a need. Do not infer clean-install correctness from a warm cache.
- [ ] Verify exact GitHub check context names from an actual CI run. Read active rules/protection again: the research baseline was unprotected main with zero active rules. Prepare the smallest ruleset change requiring successful `make-all` and the existing PR-description check, with no agent bypass. Preserve unrelated review/merge settings; bind expected check providers when supported.
- [ ] Apply the reviewed ruleset through the authorized admin capability and read it back. If that capability is unavailable, mark remote enforcement blocked; do not report workflow changes alone as mandatory protection. Check that the App identity used for merging cannot bypass the rules.
- [ ] Validate using disposable, controlled passing and deliberately failing PRs when authorized for integration testing. The normal agent merge path must be rejected for failing required checks. Also inspect workflow edits to ensure a skipped job cannot masquerade as documentation success.
- [ ] Record Linux coverage and exact validated ref/runtime in CI artifacts. Add `merge_group` only if native GitHub queue use is actually enabled; current host-queue operation does not imply that event.

**Milestone A exit:** Tasks 1–6 pass; active protection is read back; the initial coverage boundary and remaining debts are reported. No claim of completed runtime repair or mechanically verified reviewer provenance.

## Task 7: Enforce host-stamped independent documentation review

**Separate follow-up feature. Dependency:** repair R1 makes managed queue ownership reachable from normal registry startup. Scope this as its own Spec Kit feature before implementation. FR-07–FR-09, FR-12.

**Files:** the host provenance area in the file map; existing [workflow-control tests](../../../elixir/test/symphony_plus/github_workflow_control_test.exs), [dynamic-tool tests](../../../elixir/test/symphony_plus/dynamic_tool_test.exs), [merge-queue tests](../../../elixir/test/symphony_plus/github_merge_queue_test.exs), and [app-server tests](../../../elixir/test/symphony_plus/app_server_test.exs).

**Interfaces/contract:** add `workflow_control.documentation_review_required` boolean, default false for compatibility; reject non-booleans. Enable it for this repository only after verification. Host-controlled optional checkpoint field `documentation_review` contains version 1, author thread ID, reviewer thread ID, reviewed source SHA, and the review assessment/evidence references. IDs/SHA are taken from trusted session/trigger context, not model-supplied identity fields. No secrets, prompts, transcripts, or new database.

- [ ] Write focused failing tests rejecting author-thread queue admission, missing/stale provenance, forged tool identity fields, forged reserved checkpoint comments through the generic API tool, and source-head mismatch; accept a distinct fresh automatic-review thread for the exact source head. Test missing legacy metadata causes a fresh handoff/review rather than silent acceptance.
- [ ] Carry trusted app-server thread metadata through dynamic-tool execution; stamp the producer thread on `review_pending` and the reviewer provenance on successful required-mode `merge_queued`. Add a small `GitHub.DocumentationReview` module with pure provenance validation/stamping functions and adjacent specs.
- [ ] Extend existing checkpoint normalization/validation and trusted queue loading/admission to preserve and revalidate that metadata. In required mode, reject generic `github_api` comment creation/update containing reserved workflow-control markers; require the canonical checkpoint tool so agent-supplied raw comments cannot bypass host stamping. Host queue code continues using the validated host path. An author-written PR checkbox or comment must not independently satisfy admission. Keep backward-compatible mode explicit; do not accidentally strand old workflows that have not opted in.
- [ ] Preserve source versus integration-candidate semantics. Host-only conflict-free updates retain `(reviewed source SHA, target SHA, candidate SHA)` and require fresh candidate checks. Manual/repair source changes invalidate review; target movement invalidates candidate evidence. Do not trigger endless review after each host update.
- [ ] Add restart recovery, repeated-poll idempotency, missing-review capability, and changed-head tests. Prove the fresh reviewer invocation is a different native thread rather than relying on prompt wording.
- [ ] Run targeted app-server/tool/workflow/queue tests and the complete gate. Enable required mode in self-hosting only when public-startup integration passes. Report mechanical provenance separately from the AI's semantic judgment, which cannot be proven by metadata.

## Task 8: Verify cold installation and candidate release instructions

**Separate follow-up deliverable. Files:** [Burrito workflow](../../../.github/workflows/burrito-release.yml), proposed release-smoke script, existing [release contract test](../../../elixir/test/symphony_plus/release_contract_test.exs), and canonical source/release guides. FR-03, FR-04, FR-11.

- [ ] Add a cold-install scenario that follows the published source setup sequence in a clean disposable checkout. Keep downloads/network out of the fast PR scenario suite; record the tested commit and tool versions. Do not rewrite the launch flags during the check.
- [ ] Extend candidate smoke from merely expecting the missing-acknowledgement banner to executing the published acknowledged empty-service command, asserting HTTP readiness and zero registrations, then cleanly terminating it. Test the actual candidate artifact, not a source-only helper.
- [ ] Run on `linux_x86_64`, `linux_arm64`, `macos_x86_64`, and `macos_arm64`; establish platform-appropriate process cleanup and no need for Codex credentials when no work is registered.
- [ ] Make publication depend on candidate smoke. Add version/tag-specific documentation links and artifact-name verification. A post-publication smoke may be added as detection, but cannot substitute for a pre-publication gate.
- [ ] Validate a deliberately broken candidate command in an isolated fixture; publishing must remain blocked. Preserve existing stable/nightly naming and checksum behavior.

## Task 9: Add controlled external audits and agent repair routing

**Separate follow-up deliverable. Files:** proposed canary workflow, existing opt-in provider tests, maintenance guide, approved operator configuration outside the repository. FR-09–FR-11.

- [ ] Identify existing dedicated private test repository/App access and Codex test capability without reading secret contents into output. Missing capability is `unavailable`, not passed; no runtime dependency on production tracker work.
- [ ] Add trusted-default-branch-only manual/scheduled checks for App check/status permissions, authenticated private cloning, and bounded Codex compatibility. Use existing approved host profiles/resources, one concurrency group per shared fixture, a bounded work budget, and explicit cleanup. Never execute untrusted PR code with those credentials.
- [ ] Keep outstanding intended-behavior diagnostics on the default branch/local lane, not as expected-red checks on PR heads. Preserve actual failed outcomes/logs. A known defect remains a real failure; the report also distinguishes known/new/unavailable evidence.
- [ ] Emit a dated summary with source ref, environment, scenarios, raw artifact links, last successful external verification, and failures. Upload even when checks fail; never mask failure with a green “all contracts verified” conclusion.
- [ ] Route actionable findings through the existing authorized Symphony Plus work intake/repair-PR flow, deduplicated by scenario and failure signature. Verify the chosen App can push repair branches and trigger normal required CI. Do not assume `GITHUB_TOKEN`-created PRs have the same autonomous triggering behavior.
- [ ] Add a missing-credential fixture and an external-failure fixture. They must produce unavailable/failed evidence and an actionable repair/blocker report without secret leakage or production mutation.
- [ ] Document schedule delays/inactivity limitations and stale-evidence reporting. This task implements any schedule later; planning this task does not create an automation now.

## Required runtime repairs: focused implementation plans

These are required corrections managed by the [companion remediation plan](2026-10-26-existing-documentation-findings-remediation.md), and dependencies for expanding coverage. They are not hidden implementation work inside prevention Tasks 1–6. Preserve approved intent. Each repair needs its own focused failing public-process/OTP acceptance test, feature-specific design, targeted checks, full gate, and updated limitation documentation. A limitation note mitigates the risk but does not close a confirmed runtime defect.

| Repair | Audit IDs | Main source area | Acceptance and dependency |
|---|---|---|---|
| R1: registry runtime ownership | 7 | [Application](../../../elixir/lib/symphony_plus.ex), [ProjectRuntime](../../../elixir/lib/symphony_plus/project_runtime.ex), update/queue owners | A normal documented launch actually owns and exercises enabled update/queue workers without cross-project policy leakage. Prerequisite for meaningful R4 and Task 7 integration. |
| R2: safe workflow reload | 8 | [ProjectRuntime](../../../elixir/lib/symphony_plus/project_runtime.ex), [WorkflowStore](../../../elixir/lib/symphony_plus/workflow_store.ex) | Invalid reload retains last good config and running work; valid policy/prompt changes do not terminate admitted work unexpectedly. Independent of R1. |
| R3: managed-review control | 14–15 | [WorkflowControl](../../../elixir/lib/symphony_plus/github/workflow_control.ex), GitHub client/tools | Authorized cancel/status/revise act as documented; externally closed/merged PRs reconcile without stranded issues. Test every applicable checkpoint state. |
| R4: executable update activation | 9 | [SourceUpdate](../../../elixir/lib/symphony_plus/source_update.ex), [handoff helper](../../../elixir/scripts/apply-source-update), [launcher](../../../elixir/scripts/run-github) | A local disposable Git remote produces a prepared new executable that becomes the running service, retaining workflow/profile/port/data-root; failure preserves a usable prior launch. Depends on R1 for public-runtime coverage. |
| R5: quota/recovery contracts | 27–30 | [Orchestrator](../../../elixir/lib/symphony_plus/orchestrator.ex), [AgentRunner](../../../elixir/lib/symphony_plus/agent_runner.ex), [QuotaWaitStore](../../../elixir/lib/symphony_plus/quota_wait_store.ex) | Workflow-relative roots and SSH host identity survive restart; state/host limits and terminal cleanup apply to resumes. Use protocol/SSH fixtures first; real quota evidence remains explicit. |
| R6: observability/audit trail | 11, 19–20 | [Presenter](../../../elixir/lib/symphony_plus_web/presenter.ex), GitHub checkpoint/queue completion | Registry refresh reaches intended project schedulers; final ledger/cursor claims are implemented or deliberately narrowed through the approved contract process. |
| R7: private App onboarding | 12, 17 | [AppProfile](../../../elixir/lib/symphony_plus/github/app_profile.ex), Git bootstrap | Correct required check/status permissions and private clone access are both verified; mere repository visibility does not certify complete permissions. External evidence depends on dedicated resources. |

Every repair promotes its passing scenario into required coverage. No broad `skip`/`xfail`, assertions that a bug remains present, or blanket suppression of expected failures. Until a repair is complete, the maintenance guide states the limitation and the CI report states the narrower coverage boundary.

## Verification and agent handoff

- [ ] Confirm requirement coverage: FR-01/02 → Tasks 1/5; FR-03/04/05 → Tasks 2/3; FR-06 → Task 4; FR-07 → Tasks 5/7; FR-08 → Task 6; FR-09/10 → Task 3 and repair roadmap; FR-11 → Tasks 8/9; FR-12 → mutation/negative checks in Tasks 2/3/4/6/7/8/9.
- [ ] Confirm FR-13 coverage through companion remediation Tasks 1–9 and every row of its closure matrix.
- [ ] Prove the gate fails on an isolated missing-ack command, wrong target workflow, stale reference, and broken observable behavior; prove fixture cleanup after each failure.
- [ ] Run the complete [Makefile](../../../elixir/Makefile) quality gate once changes are implemented and inspect fresh output. Avoid repeating it without new changes/failures.
- [ ] Independently review changed code, canonical docs, evidence freshness, and remaining limitations. Preserve the existing PR template and report exact source/candidate SHA semantics.
- [ ] Read back effective GitHub rules and check contexts; remote enforcement remains incomplete if missing or bypassable by the automation identity.
- [ ] Report completed milestone, scenario/OS coverage, failed/unavailable external checks, known unresolved repairs, and actual CI links. Do not report all documentation guaranteed correct.
- [ ] For overall delivery, reconcile every finding against the companion plan's 37-row closure matrix. Do not report the existing findings corrected merely because they have been mapped or mitigated.

## Planning self-review

The design requirements map to named tasks above; five high-risk input classes have assigned tests. New proposed function/task names are consistent across tasks. The reviewed scope explicitly separates initial protection, host provenance, runtime repairs, and external/release work. An independent builder review identified missing mechanical provenance, integration-candidate semantics, and milestone boundaries; the design and this plan now make those choices explicit. No product implementation is authorized by completing this planning deliverable.
