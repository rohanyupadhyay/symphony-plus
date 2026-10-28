# Agent-owned documentation correctness design

Status: implementation authorized by the user. See the [delivery record](../plans/2026-10-26-agent-owned-documentation.md#delivery-record--2026-10-28) and [maintenance evidence](../../../elixir/docs/documentation-maintenance.md) for actual completion and external limitations.

## Intent

Agents own keeping Symphony Plus's operational documentation accurate. A feature is incomplete when its changed commands, configuration, or behavior disagree with the applicable documentation or lack required verification evidence. Normal delivery must not depend on a human noticing README drift.

The current constitution already requires documentation updates; the missing mechanisms are executable acceptance, evidence-aware agent work, and enforced merge checks. See the [research](../research/2026-10-26-agent-owned-documentation-research.md).

## Requirements

| ID | Requirement |
|---|---|
| FR-01 | The constitution assigns documentation impact analysis, updates, verification, and repair to the implementing agent. |
| FR-02 | Feature plans/tasks identify affected operator claims, canonical documentation, and concrete verification; justified no-impact decisions remain reviewable. |
| FR-03 | Critical shell instructions are tested from their actual published bodies through the built public executable. Tests must not silently insert missing flags or replace the command under test. |
| FR-04 | Fixtures isolate cwd, HOME/XDG/Codex configuration, registry/log/workspace paths, credentials, ports, and subprocesses. Required checks cannot dispatch real tracker work. |
| FR-05 | Initial behavior coverage proves acknowledgement handling, empty startup, explicit registration, persistence, CLI targeting, and unavailable/repaired registration visibility. |
| FR-06 | Declared defaults, supported flags, tool versions, and release targets have bounded generated reference material checked for drift. |
| FR-07 | Narrative claims receive independent agent review tied to the reviewed source head and current CI evidence. Author/repair commits invalidate that review; host-only integration candidates retain explicitly recorded source/target/candidate lineage and require candidate CI. |
| FR-08 | The existing unconditional quality gate includes documentation checks; effective repository rules require successful checks before agent merge. |
| FR-09 | Known implementation defects remain visible and traceable; agents must not weaken approved intent, blanket-skip failing contracts, or claim missing external validation passed. |
| FR-10 | Runtime repair work is split into focused changes that add and promote the corresponding documented-behavior tests. |
| FR-11 | Controlled external checks and candidate release checks supplement deterministic PR checks. External unavailability is explicit. |
| FR-12 | Gate regression checks demonstrate that missing flags, wrong workflow selection, stale generated facts, and broken observable behavior produce failures. |
| FR-13 | Correct the existing 37 findings as required delivery work, with per-finding closure evidence. Documentation mitigations do not close confirmed implementation defects; unavailable external checks remain blocked. |

## Approaches considered

1. **Constitution and agent review only:** low setup cost, but the current repository demonstrates that instructions and prose review alone miss drift.
2. **Generate documentation broadly from code:** removes repeated metadata but risks describing implementation defects as intended behavior and cannot verify operator workflows.
3. **Curated executable examples, bounded generation, and agent review, enforced by CI:** recommended. It reuses ExUnit, Ecto, Spec Kit overrides, existing managed review, and GitHub Actions. It adds evidence where drift matters without creating a general documentation platform.

The user subsequently authorized implementation of the plan and existing-finding repairs. Approach 3 is implemented under that authorization.

## Architecture

### Governance and Spec Kit

Amend the constitution to require verified documentation contracts rather than file-touch evidence. Clarify that independent PR review may be performed by a separate agent context where repository policy permits it; preserve the existing spec/plan/implementation approval checkpoints and GitHub-required reviews. Because this replaces the blanket human-review requirement, the combined amendment is a MAJOR version change from 1.1.0 to 2.0.0. Do not commit a constitutional version change as part of planning.

Use project-owned plan/tasks template overrides, the existing agent guide, and repository workflow prompts. Do not edit the installed Spec Kit skills or their integration manifests. Planning maps each affected claim to an observable acceptance scenario or explicit external verification. Analyze enforces the declared obligations; converge checks those same artifacts and appends unmet work using its existing append-only contract.

### Canonical instructions and executable scenarios

Keep the root README concise: build prerequisites, a tested source installation sequence, a tested empty-service start, and links to provider onboarding. The Elixir guide owns detailed invocation/configuration; the self-hosting guide owns concrete local profiles and paths. Avoid maintaining competing generic launch commands.

Mark selected shell fences with a stable HTML comment immediately before the fence, for example `<!-- docs:scenario service-start -->`. A fixed scenario map in test support declares the expected file, cwd, fixture setup, and assertions. Missing, duplicate, or moved expected blocks fail clearly. There is no generic evaluator for arbitrary fences and no automatic execution of secret-bearing examples.

The helper extracts the exact block text and runs it with Bash. Fixture paths/ports are provided through environment variables explicitly documented in those blocks. The harness never repairs command text. Source-install blocks with network/tool downloads are classified separately from PR-local runtime blocks and exercised by cold-install checks.

The public process is the freshly built development escript. Test callbacks do not replace CLI startup or application supervision. Use synchronous HTTP/persistence observations and bounded readiness polling. Initial PR coverage uses the memory tracker with no issues; tracker/Codex fixtures are added only when a specific behavior requires them.

### Generated facts

Add `mix docs.generate` and `mix docs.check`, with the latter rendering in memory and comparing without writing. One reference page owns generated facts; READMEs link to it. Reuse CLI parser declarations and schema structs without calling environment-dependent runtime configuration or reading profiles. Distinguish declared defaults from effective service configuration. No new schema/validation library is required.

### Independent agent review

Before implementation, the author records a short documentation-impact table in the feature plan. Before merge, a fresh reviewer context examines the changed code, applicable documentation, intended contract, and current evidence. Use the existing automatic-review cycle's fresh invocation; verify its thread identity rather than assuming a new prompt makes it independent.

The review records reviewed source SHA, documentation changes/justified exclusions, evidence references, unresolved findings, and external limitations under existing PR/checkpoint sections. An author checkbox is not proof of independence. The reviewer cannot certify new author/repair commits with an old result; corrections require another review of the resulting source head. If a fresh reviewer context cannot be established, report the review as unavailable and do not claim this requirement satisfied.

Mechanical provenance enforcement is a separate follow-up deliverable, not something the existing PR-description validator can prove. Add an opt-in `tracker.provider.workflow_control.documentation_review_required` boolean, default false for compatibility and enabled for self-hosting after its focused implementation passes. In that mode the host stamps the producer thread ID on review handoff, obtains reviewer identity from the actual app-server session rather than tool arguments, and only accepts `merge_queued` after a fresh automatic-review context assesses the exact source head. Persist bounded versioned provenance alongside the existing trusted checkpoint, and verify it again during queue loading/admission. Generic `github_api` comment writes containing reserved control markers must be rejected in required mode so they cannot bypass the canonical host-stamping path. An agent-provided assessment is still judgment, not mechanical proof of prose truth. Missing legacy provenance triggers a fresh handoff/review; it must not silently waive the requirement. No additional GitHub App identity, review database, or generic agent framework is needed.

The current queue deliberately creates integration candidates after source review. Preserve that model: a host-only, conflict-free update records `(reviewed source SHA, target SHA, candidate SHA)` and reruns the required checks on the candidate. It does not claim that the reviewer examined the candidate SHA. An author correction or manual branch change requires a new source review; target movement invalidates candidate evidence and rebuilds the lineage. This avoids a review/update loop. Admission must fail when provenance or lineage is missing/mismatched in required mode.

### Local and CI entrypoints

- `make -C elixir docs-check`: build a development escript, check generated facts/local references/example configuration, and run the selected documentation-tagged tests.
- `make -C elixir all`: keep the current build/static checks/coverage/Dialyzer flow; add non-writing documentation checks and execute scenario tests once through coverage.
- Keep the existing GitHub `make-all` job unconditional. Required documentation execution has no credential condition or path-based skip.
- Configure repository enforcement only after successful checks exist. Require `make-all` and the existing PR-description context, preserve unrelated settings, and verify active policy/bypass rules through read-back.

These interfaces are implemented; source and acceptance-test links appear in the maintenance guide.

### Repair and external-validation lanes

Deliver startup/documentation protection before attempting every runtime repair. The maintenance guide retains a concise debt table for known mismatches, linking intended contracts and repairs. No `.t` transcript, JSON claims registry, custom service, or issue database is introduced solely to manage this table.

Focused repair lanes then cover reload, update/queue lifecycle ownership, managed review control, executable handoff, quota recovery, and observability/audit trails. Each repair has a failing observable scenario and promotes that scenario into the required suite when fixed.

Default-branch diagnostics can run outstanding intended-behavior scenarios and remain failed while defects exist. They must not run on PR heads until passing, because the host coordinator considers all failed check runs. External canaries run only trusted default-branch code against dedicated resources; candidate binary smoke checks run before release publication. Schedule/canary setup is a later implementation deliverable, not an automation created by this plan.

## Acceptance criteria

1. Removing acknowledgement from a fixture copy of the documented launch command fails with a useful location; the harness does not add it back.
2. Substituting the bundled workflow for the configured target fails the project identity assertion.
3. Running list/add/remove from a different cwd with documented data-root/service-url options targets the same instance; two independently configured instances do not share registration state.
4. Changing a generated fact without regeneration fails the non-writing check; generation is deterministic with poisoned secret environment variables.
5. The real CLI starts with zero registrations, adds a valid workflow, preserves registration after restart, and exposes unavailable/repaired registration state.
6. A failed readiness assertion or timeout leaves no test-owned process, listener, registry, or workspace behind.
7. New author/repair commits invalidate prior source review. Host-generated integration candidates carry explicit source/target/candidate lineage and passing candidate checks; stale or unavailable evidence is never reported as current success.
8. The required check runs on every applicable PR and the repository's active rules require it; a controlled failing PR cannot merge through the normal agent path.
9. Cold installation and candidate binary checks state their tested runtime/OS/ref. External checks clearly distinguish failed, unavailable, and passed.
10. Known intended-behavior defects remain documented until repaired; completion reports name the initial coverage boundary.

## Non-goals and constraints

- No promise of complete semantic proof for arbitrary prose or future provider behavior.
- No replacement of existing Spec Kit, Ecto, or GitHub App architecture.
- No broad runtime refactor or all-37-findings repair inside the first infrastructure change.
- No silent removal of existing product approvals, required GitHub reviews, or merge policy.
- No routine human documentation review or manual README synchronization step.
- No live credentials or production tracker work in PR checks; no automatic execution of every Markdown fence.
- Preserve Elixir 1.19.5/OTP 28, installed Spec Kit 1.0.12, existing PR headings, and the existing main quality gate.

## Rollout and decision boundaries

The first implementation milestone is bounded: constitutional/template obligations, corrected canonical startup, curated process tests, generated facts, local checks, and required GitHub CI. It provides deterministic documentation protection plus workflow-level independent review; it does not claim host-enforced review provenance is implemented.

The next milestone adds the focused review-provenance contract after the existing registry/queue lifecycle repair is available. Existing-finding corrections are required companion delivery work under the [remediation plan](../plans/2026-10-26-existing-documentation-findings-remediation.md). They remain separately scoped changes to keep runtime repairs reviewable, not indefinitely deferred backlog. Immediate factual/operator fixes run alongside the first prevention milestone. Every finding has a closure criterion; documenting a limitation mitigates an implementation defect without resolving it. Later rollout wires trusted external diagnostics and pre-publication release checks. Completing the first prevention milestone must not be reported as completing all corrective and prevention work.

An agent can execute all routine work after approval of the implementation scope. Administrative access or absent test credentials are capabilities to verify, not reasons to claim enforcement is complete.

Open implementation-time checks are factual: current GitHub permissions/policy, fresh reviewer thread behavior, exact CI context names, process cleanup portability, and availability of dedicated external resources. The recommended architecture does not depend on silently assuming these checks pass.
