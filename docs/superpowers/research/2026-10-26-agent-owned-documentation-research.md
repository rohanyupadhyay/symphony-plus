# Research: agent-owned documentation correctness

Date: 2026-10-26. Repository baseline: `16283fcc7c904549f9bba4a1a4b7cb812e260102`.

## Question and conclusion

How can agents keep operational documentation correct as Symphony Plus changes, without routine human documentation work?

Use three connected layers: a constitutional delivery obligation, deterministic executable evidence in the existing quality gate, and independent agent review of narrative claims. Generate a small factual reference from existing metadata. Start with actual startup and registry commands, then expand behavior coverage as separate runtime defects are repaired. A constitution amendment alone cannot install or enforce these mechanisms.

This records research at the baseline above. The user subsequently authorized implementation;
see the [delivery record](../plans/2026-10-26-agent-owned-documentation.md#delivery-record--2026-10-28)
and [current maintenance evidence](../../../elixir/docs/documentation-maintenance.md) for changes and limits.

## Repository evidence

| Observation | Evidence | Consequence |
|---|---|---|
| Documentation updates are already mandatory | [Constitution principles I and VI](../../../.specify/memory/constitution.md) | Adding another generic “update docs” rule is insufficient. Require demonstrated correctness. |
| Current documentation tests mostly check names/links | [DocumentationContractTest](../../../elixir/test/symphony_plus/documentation_contract_test.exs) | They can pass while launch instructions fail. |
| A CLI test's name overstates its assertions | [CLITest](../../../elixir/test/symphony_plus/cli_test.exs), original test “defaults to WORKFLOW.md” (renamed during implementation) | Test real entrypoints and outcomes rather than accepting a stubbed `:ok`. |
| Core task template describes tests as optional | [tasks-template.md](../../../.specify/templates/tasks-template.md) | Add repository-owned overrides making affected documentation contracts explicit tasks. |
| Template overrides are supported | [common.sh](../../../.specify/scripts/bash/common.sh), `resolve_template_content` | Use `.specify/templates/overrides/`; do not patch installed skills. |
| Planning, analysis, implementation, and convergence read project intent | [plan skill](../../../.agents/skills/speckit-plan/SKILL.md), [analyze skill](../../../.agents/skills/speckit-analyze/SKILL.md), [converge skill](../../../.agents/skills/speckit-converge/SKILL.md) | Put documentation acceptance criteria into feature plans/tasks; converge can then append missing work without becoming a diff-based audit. |
| Normal quality gate builds before coverage | [Makefile](../../../elixir/Makefile), [make-all workflow](../../../.github/workflows/make-all.yml) | Extend the existing gate, retaining its check name. Build a development escript, not a test-configured executable. |
| Merge coordinator accepts skipped/neutral checks and observes all failures | [MergeQueue.Backend](../../../elixir/lib/symphony_plus/github/merge_queue/backend.ex), `candidate_checks` | Workflow files alone do not enforce a required gate. Deliberately red diagnostic checks on PR heads would interfere even if not required by GitHub. |
| Human-review wording contradicts autonomous review instructions | [Constitution](../../../.specify/memory/constitution.md), [self-hosting workflow](../../../.symphony-plus/WORKFLOW.md) | Amend governance explicitly, preserving product approval checkpoints and repository merge policy. |
| Installed Spec Kit is 1.0.12; runtime is Elixir 1.19.5/OTP 28 | [integration manifest](../../../.specify/integration.json), [mise.toml](../../../elixir/mise.toml) | Use installed interfaces; no upgrade is needed for this work. |

Read-only GitHub checks on 2026-10-26 returned:

- `GET /repos/rohanyupadhyay/symphony-plus/branches/main/protection`: HTTP 404, “Branch not protected”.
- `GET /repos/rohanyupadhyay/symphony-plus/rules/branches/main`: `[]`.
- `GET /repos/rohanyupadhyay/symphony-plus/rulesets`: `[]`.

At that baseline, checks were not enforced by either classic protection or active rulesets. These observations are time-bounded; the implementation agent must read current settings before configuring anything and preserve unrelated policy.

## Prior art and decisions

### 1. Executable examples

Rust [rustdoc](https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html) and [Sphinx doctest](https://www.sphinx-doc.org/en/master/usage/extensions/doctest.html) execute documented examples. The transferable principle is to test the example the reader sees.

**Decision:** a small ExUnit helper extracts explicitly identified shell fences and executes their unchanged bodies against the freshly built escript. A fixed set of scenarios owns setup and assertions. Do not execute arbitrary Markdown automatically.

**Alternative:** canonical executable scripts plus generated README snippets. This reduces duplication, but parity alone does not verify prose prerequisites, working directory, or the assembled onboarding sequence. Adopt shared scripts only when the same command truly needs multiple presentations.

**Alternative:** [Cram](https://github.com/aiiie/cram#readme) or [Sybil](https://sybil.readthedocs.io/en/latest/markdown.html#other-languages). Both offer useful document-testing patterns, but introduce a Python toolchain and still need process isolation and fixture design. Existing ExUnit is sufficient for the initial curated scenarios.

The pinned [Elixir 1.19 source](https://github.com/elixir-lang/elixir/blob/v1.19.0/lib/ex_unit/lib/ex_unit/doc_test.ex) already includes `doctest_file/2` (introduced in 1.15). Its limitation here is that it parses `iex>` examples rather than shell commands; doctests also provide no execution sandbox. Do not recommend a runtime upgrade merely to test Markdown.

### 2. Generated reference facts

Kubernetes [generates kubectl reference documentation from source](https://kubernetes.io/docs/contribute/generate-ref-docs/kubectl/). [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html#docs/2) demonstrates an Elixir schema used for validation and generated documentation.

**Decision:** retain the existing Ecto schema and CLI parser. Generate one bounded reference page for runtime versions, release targets, service flags, and selected declared defaults. Obtain CLI metadata from the same declaration used by parsing. Never resolve host secrets or environment values during generation. Describe effective/context-dependent behavior in separately tested prose.

**Rejected:** migrating validation libraries or generating narrative lifecycle explanations. Metadata consistency cannot establish that the implementation satisfies the intended behavior.

### 3. Agent-owned delivery and review

GitLab's [documentation workflow](https://docs.gitlab.com/development/documentation/workflow/) makes documentation part of delivering product changes and calls for technical review. Here the implementing agent owns those updates, while a separate review context checks the operator experience and evidence.

**Decision:** put durable requirements in the constitution, make feature-specific work explicit through template overrides, and enforce actual execution through CI. Reuse the existing managed automatic-review phase; require a fresh reviewer context and exact reviewed SHA rather than an author-written “docs checked” box. Preserve spec, plan, and implementation approval checkpoints.

**Rejected as sole enforcement:** filename-touch rules, substring tests, broad periodic AI rewrites, or a reviewer merely accepting the author's summary. These do not demonstrate behavior.

Independent builder review exposed two design decisions that cannot be left implicit: PR text cannot establish reviewer independence, and requiring a fresh review after every queue-created merge candidate would fight the existing integration model. The proposal therefore separates initial workflow-level review from a later host-stamped provenance contract, and distinguishes reviewed source commits from host-generated integration candidates with their own required CI. These are explicit scope/architecture choices, not assumptions that today's host already enforces them.

**Hooks:** installed skills expose extension hooks, but their handling can skip conditions and continue after malformed hook YAML. Template overrides plus CI are simpler for this task; hooks must not be the sole mandatory gate.

### 4. Merge enforcement

GitHub [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) support required checks and [rules APIs](https://docs.github.com/en/rest/repos/rules) expose effective policy. [Skipped jobs count as success](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions), so a nominally required but conditional job is insufficient.

**Decision:** retain the unconditional `make-all` check, add documentation verification to what it executes, and configure an active ruleset requiring successful expected check contexts. Prevent the automation identity from bypassing that rule. Verify policy by read-back; a committed workflow is not the same as enforcement. Do not silently modify unrelated review counts, merge methods, or actor privileges.

This project has a host-owned merge coordinator, not evidence of GitHub's native merge queue being enabled. Add a [`merge_group` trigger](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#merge_group) only when native GitHub queue use is confirmed. Supporting it preemptively is harmless, but it is not a prerequisite for the current host queue.

### 5. External and release verification

**Decision:** keep PR checks credential-free and deterministic. Add separate trusted default-branch canaries for private-repository App permissions, authenticated cloning, and Codex compatibility using dedicated resources. Missing credentials mean `unavailable`, not passed. Agent repair PRs should use the existing approved App workflow; do not add an unrelated AI service or expose secrets to PR code.

Run release instruction checks on candidate binaries on all four supported targets before publication. A post-publication check detects a broken release but cannot prevent publishing it. Keep development instructions linked to the development branch and release instructions linked to the corresponding tag/commit.

GitHub's [schedule documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule) describes delayed/dropped runs and inactivity behavior. Scheduled audits are time-bounded evidence, not continuous guarantees. This plan proposes their implementation; it does not create a persistent automation.

GitHub's [`GITHUB_TOKEN` documentation](https://docs.github.com/en/actions/concepts/security/github_token) also explains restrictions on workflow-triggering automation. Use the operator-owned App for autonomous repair pushes where already authorized; otherwise record a blocked capability rather than claiming the repair pipeline is autonomous.

## Treatment of the 37 audit findings

These groups preserve the original audit IDs so subsequent repair work remains traceable. IDs are historical references, not a new generic claims database.

| IDs | Workstream | Examples and disposition |
|---|---|---|
| 1–6 | Command/setup corrections | Required acknowledgement; actual target workflow; empty-registry semantics; explicit service port; isolated data roots; CLI targeting flags. Address before promoting startup checks. |
| 7–9 | Runtime repair dependencies | Registry startup lacks update/queue workers; reload stops runtime; update activation does not install the prepared executable. Preserve intended requirements and document temporary limitations. |
| 10–11 | Observability | Explain disabled terminal UI; track broken registry refresh as a runtime repair. |
| 12–18 | GitHub onboarding/control | Correct App permissions, merge-policy conflicts, target-specific validators, private cloning prerequisites, hook trust. Repair ignored managed-review commands and external merge/closure handling separately. |
| 19–20 | Review audit trail | Final phase-ledger and cursor claims need implementation support or explicitly approved narrowing. |
| 21–26 | Configuration precision | Configured terminal states, approval-policy exceptions, required provider states, Jira refresh scope, Asana eligibility, independent stall timeout. |
| 27–30 | Quota repairs | Relative roots, SSH host persistence, state/host concurrency, terminal cleanup. These are intended-behavior debts, not assertions to redefine around bugs. |
| 31–35 | Prerequisites/testing/versioning | Bash, test cwd, physical Codex auth file, correct Plus specification link, stale binary example. |
| 36–37 | Presentation | Historical screenshot and misplaced introduction/provider-specific setup labels. |

The root [reload contract](../../../SPEC.md) and the [quota feature specification](../../../specs/gh-8-quota-renewal-resume/spec.md) are authority above current buggy behavior. An agent must not make CI green by weakening those requirements.

The [companion remediation plan](../plans/2026-10-26-existing-documentation-findings-remediation.md) makes these corrections required work and assigns every original finding an observable closure criterion. Separate PRs are an execution boundary, not permission to leave the findings indefinitely open. Temporary limitation documentation mitigates confirmed runtime defects but does not close them.

## Baseline and diagnostic staging

The initial required gate covers implemented startup/registry/configuration contracts and factual consistency. Maintain a small operator-visible debt table in the focused documentation-maintenance guide with source references, reproducer, intended outcome, workaround, and repair dependency. Do not say the entire documented product is verified while baseline defects remain.

Known-failing intended-behavior diagnostics must not be attached to PR heads as supposedly harmless non-required checks: the current host merge coordinator considers all failed checks. Run them locally or in a trusted default-branch-only diagnostic workflow. A failed diagnostic remains failed, with raw results and artifacts; it is not `xfail`, skipped, or relabeled success. New passing repaired scenarios are promoted into the required suite by their repair PR. Missing diagnostics and stale external evidence are reported explicitly.

## Limits

- Tests establish behavior only for their scenarios, environments, and tested versions.
- Generation establishes agreement with metadata, not truth of all prose.
- Independent agent review can miss omissions; it supplements deterministic evidence.
- Enforcement depends on effective repository rules and their bypass configuration.
- Private permissions, real quota/SSH recovery, and release activation need controlled live evidence beyond local fixtures.
- The previous audit's 44 focused tests passed despite documentation discrepancies. This research adds no claim that runtime defects have been repaired.
