# Agent-owned documentation maintenance

Agents own documentation impact assessment, correction, exact-command verification, and independent
review. Human product checkpoints and GitHub-required reviews remain binding. Constitution 2.0.0
states the obligation; repository-owned Spec Kit 1.0.12 template overrides carry the planning/task
requirements. Installed skills and integration manifests are unchanged.

From `elixir/`, `make docs-check` builds the current development escript, compares generated facts
without writing, checks scoped operator links and App bootstrap examples, and runs tests tagged
`documentation`. `make all` checks the generated reference and those links/examples
and runs those scenarios once through normal coverage. Direct `make test` and `make coverage`
also build the executable first. `mix docs.generate` deliberately regenerates
[configuration facts](configuration-reference.md) from raw Ecto schema defaults and CLI parser
option types, plus pinned mise tool versions, the Mix project version, and declared Burrito targets,
without resolving host credentials or path/environment defaults.

The fixed scenario map in `documentation_examples_test.exs` executes the exact bytes of the four
marked Bash fences in the [canonical installation guide](../README.md#install-and-run-from-source).
The inputs named in that guide select the actual executable, service, workflow, logs, and data
root. Fixtures use temporary cwd/HOME/XDG/Codex/data/workspace roots and an allowlisted environment,
empty memory trackers, no user hooks, and dedicated Linux process groups. They prove HTTP health,
empty startup, registration identity, restart persistence, offline listing from another cwd,
idle removal preserving files, two-instance isolation, missing-workflow repair, acknowledgement
rejection, and wrong-address/path failures. Timeouts and assertion failures clean up processes.
These checks do not automatically execute arbitrary Markdown or certify unrelated shell fences.

This local deterministic lane establishes Linux behavior. The Burrito release workflow runs the
marked `release-service-start` command against each candidate executable on Linux and macOS,
checks HTTP readiness and zero projects, and blocks publication if any target fails. The first
[post-merge nightly](https://github.com/rohanyupadhyay/symphony-plus/actions/runs/40639531701), source
`7eb757b1e0e7ffbd9ae40eead656a06b44a8026f`, passed builds and these command smokes on all four
Linux/macOS x86_64/arm64 targets before publication on 2026-10-28. A disposable
cold source installation and the controlled private GitHub/Codex canary report dated execution
evidence separately. On 2026-10-28 the published cold-install block passed from an isolated HOME,
cloning public default-branch commit `16283fcc7c904549f9bba4a1a4b7cb812e260102` and installing
OTP 28.5 / Elixir 1.19.5 before `mix setup` and `mix build`. This verifies the source-install
sequence against that public revision, not the new branch or all release platforms. Unavailable capability is never a passing result. The configured unconditional
`make-all` workflow includes this lane; repository ruleset [26013439](https://github.com/rohanyupadhyay/symphony-plus/rules/26013439) was
applied and read back active on 2026-10-28. It requires an up-to-date PR, resolved review threads,
and successful `make-all` and `validate-pr-description` checks from GitHub Actions App 15368,
with zero bypass actors. A [controlled invalid-description run](https://github.com/rohanyupadhyay/symphony-plus/actions/runs/40638669933)
failed and GitHub reported PR #35 `BLOCKED`; the valid description was then restored. No failed
merge was attempted. The repository had no existing protection/rules to replace. Zero mandatory
human approvals preserves the requested agent workflow; explicit product approvals remain binding.
A workflow file alone does not establish this protection.

Feature plans map changed behavior to canonical sections, scenarios/generated facts, and evidence
limits. An internal refactor can explain why no operator claim changes. Analyze/converge retain
their installed scope and include declared documentation tasks. Independent review reads actual
changed code and documents at the source head, records observations, current CI evidence, unresolved
findings, and external omissions, and repeats after corrections. PR formatting validation checks
structure, not the truth of those observations. Host provenance, when enabled, verifies review
thread/source identity; it cannot establish the semantic quality of the review.

## Audit closure guide

The audit dated 2026-10-26 found 37 claims. Each row preserves the intended contract and a concrete
acceptance boundary. **Corrected guidance** means the factual text was corrected; it does not imply
that an associated external integration ran. **Fixture verified** means the repaired runtime contract passed the named deterministic regression
suite through real OTP processes or controlled provider/native-protocol fixtures; it does not imply
a live external deployment was tested.
**Unavailable** means a required external capability has not been established. No unresolved runtime
finding is closed merely by being documented here. The evidence below was checked on 2026-10-28. The branch PR supplies the exact source ref and CI
results; test-file links identify the acceptance boundary rather than claiming external coverage.

| ID | Intended contract/source | Status and current limitation | Reproducer/evidence boundary | Workaround | Repair | Acceptance criterion |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | CLI acknowledgement required | Corrected guidance | Exact `service-start` subprocess; missing acknowledgement exits 1 | Use published flag | A3 | Copied command reaches HTTP readiness |
| 2 | Customized target workflow selected | Corrected guidance | Exact `project-add` verifies canonical target path | Supply absolute target input | A3 | Registered path equals intended target |
| 3 | No implicit workflow registration | Corrected guidance | Empty startup has zero projects | Explicitly add desired workflow | A3 | Empty service stays healthy |
| 4 | Dashboard startup explicit | Corrected guidance | Published command supplies port and HTTP health check | Specify port | A3 | Service URL responds 200 |
| 5 | Independent services have independent registries | Corrected guidance | Two-process fixture uses distinct absolute roots | Distinct ports and data roots | A3 | Adding to A does not register in B |
| 6 | Registry commands address the same installation from any cwd | Corrected guidance | Offline list from different cwd; explicit URL add/remove | Repeat explicit root/URL | A3 | Restart/list/mutations target same registry |
| 7 | Enabled registry projects own queue/update workers | Fixture verified | [Runtime](../test/symphony_plus/project_runtime_test.exs), [queue ownership](../test/symphony_plus/project_queue_ownership_test.exs), and [updater](../test/symphony_plus/update_manager_test.exs) exercise registered-project supervision, duplicate authority, and installation-wide drains | Configure consistent installation update policy | R1 | One installation updater and one active repository queue authority |
| 8 | Last good workflow and admitted work survive reload | Fixture verified | [Reload regressions](../test/symphony_plus/project_runtime_test.exs) cover invalid/reverted routing, retained PIDs, independent drains, and a suspended queue | Routing changes wait for quiescence | R2 | Last good policy and retained processes survive compatible/invalid reload |
| 9 | Prepared executable becomes running service | Fixture verified; no production update performed | [Handoff fixtures](../test/symphony_plus/source_update_script_test.exs) cover executable promotion, canonical launcher cwd, original service cwd/arguments, startup readiness, delayed failure, and fallback | Manual verified rebuild/restart remains available | R4 | Candidate runs or prior executable restarts with retained arguments |
| 10 | Normal service observability is accurately described | Corrected guidance | Application disables legacy terminal renderer | Use HTTP dashboard and JSON | A3 | Docs identify terminal view as historical/disabled |
| 11 | Registry refresh reaches project schedulers | Fixture verified | [HTTP refresh](../test/symphony_plus/registry_observability_test.exs) reaches registered schedulers and reports unavailable projects | Wait for polling if a project is unavailable | R6 | Public refresh requests each available scheduler poll |
| 12 | Private App review has required endpoint access | Unavailable external evidence; permissions guidance corrected | Registration requests Checks and Commit statuses read; private resource test still required | Grant documented permissions; verify dedicated private fixture | R7 | Private current-head checks/statuses readable and guarded queue path verified |
| 13 | Merge policy distinguishes agents from host queue | Corrected guidance | Runbook/template policy review | Disable queue for human-performed merge policy | A3 | No direct-agent merge instruction; all required reviews preserved |
| 14 | Authorized managed/queued status, cancel, revise work | Fixture verified | [Control states](../test/symphony_plus/github_workflow_control_test.exs) and [queue authority](../test/symphony_plus/github_merge_queue_test.exs) exercise command precedence and safe checkpoint persistence | Inspect current checkpoint for recovery | R3 | Pending commands retain authority across queue operations |
| 15 | External PR merge/closure reconciles managed work | Fixture verified | [Managed lifecycle](../test/symphony_plus/github_workflow_control_test.exs) and [host completion](../test/symphony_plus/github_merge_queue_test.exs) cover external outcomes and retryable closure | Inspect explicit recovery checkpoint for unmerged closure | R3 | Merged work completes; closed-unmerged work exposes recovery |
| 16 | Reusable template uses target-native validation | Corrected guidance | Explicit PROJECT validation/PR-body placeholders and customization scan | Replace both command placeholders | A3 | Generic target has no accidental Symphony Plus-specific commands |
| 17 | Private bootstrap cloning is authenticated | Unavailable external evidence | Private disposable clone with host App required | Verify read authentication before dispatch | R7 | Private hook clone succeeds without exposing credentials |
| 18 | Credential boundary includes trusted hooks | Corrected guidance | Hook execution inherits host environment before child scrubbing | Audit hooks and invoked repository code | A3 | Guides state trusted-host hook boundary |
| 19 | Final managed completion preserves phase audit trail | Fixture verified | [Completion report](../test/symphony_plus/github_merge_queue_test.exs) retains trusted phase ledger and exact source/target/candidate lineage | Absent prior phase evidence remains unavailable | R6 | Final outcome retains known phases without inventing evidence |
| 20 | Review cursors match active managed checkpoint protocol | Fixture verified | [Control cursors](../test/symphony_plus/github_workflow_control_test.exs) and [review provenance](../test/symphony_plus/github_documentation_review_test.exs) cover repeated feedback and handoff | Consult current checkpoint and event IDs | R6 | Current checkpoints consume feedback without replay |
| 21 | Terminal cleanup uses configured state list | Corrected guidance | Tracker schema and lifecycle docs reviewed | Supply adapter-native state lists | A3 | Linear defaults labeled as defaults, not universal states |
| 22 | Approval handling respects never-policy exception | Corrected guidance | Existing app-server policy tests; operator wording reviewed | Configure approval policy intentionally | A3 | Never-policy auto-approval exception disclosed |
| 23 | Non-Linear required state lists explicit | Corrected guidance | Adapter validation tests; Asana/GitLab profiles corrected | Set both active and terminal lists | A3 | Missing lists cannot be mistaken for inherited defaults |
| 24 | Jira ID refresh observes terminal transitions | Corrected guidance | Jira client query semantics reviewed | Preserve project/ID filter without status filter | A3 | Candidate and ID-refresh scope described separately |
| 25 | Asana eligibility includes named section and incomplete state | Corrected guidance | Existing adapter normalization/dispatch tests | Move incomplete task to named active section | A3 | Operator can explain omitted/ineligible tasks |
| 26 | Independent stall watchdog documented | Corrected guidance | Raw schema generated default 300000; zero disable semantics | Tune both silence limits deliberately | A3 | Raising turn timeout not described as disabling watchdog |
| 27 | Workflow-relative quota roots resolve consistently | Fixture verified | [Quota recovery](../test/symphony_plus/quota_recovery_test.exs) reloads workflow-relative waits and resumes existing canonical workspaces | Absolute roots remain supported | R5 | Persistence and resume select the same canonical root |
| 28 | SSH quota worker identity survives restart | Fixture verified; live SSH unavailable | [Quota recovery](../test/symphony_plus/quota_recovery_test.exs) persists original host and refuses missing remote workspaces or unknown legacy identities | Preserve original host/workspace; legacy records block explicitly | R5 | No silent local fallback or new remote workspace during resume |
| 29 | Quota resumes obey all concurrency limits | Fixture verified | [Quota admission](../test/symphony_plus/quota_recovery_test.exs) covers state/host/global reservations and retained resume during installation drain | Tune configured limits deliberately | R5 | A retained resume respects capacity and can finish a drain |
| 30 | Terminal quota work follows cleanup policy | Fixture verified | [Quota cleanup](../test/symphony_plus/quota_recovery_test.exs) covers terminal/cancelled waits, label eligibility, and failed resume slot release | Inspect preserved workspace before manual cleanup | R5 | Terminal/cancelled waits clean safely; failures release reservations |
| 31 | Binary local-worker prerequisites include Bash | Corrected guidance | App-server launcher source reviewed | Install Bash with Git and Codex | A3 | Runtime prerequisites list Bash |
| 32 | Live examples use consistent cwd | Corrected guidance | Provider blocks start from declared elixir directory | Do not repeat cd | A3 | All five examples follow stated cwd |
| 33 | Physical auth-file prerequisite disclosed | Corrected guidance; live execution unavailable | Five existing live harnesses require auth.json | Supply authorized physical file; no credential output | A3/C | Local and Docker prerequisites both explicit |
| 34 | Custom implementations use maintained Plus contract | Corrected guidance | Root implementation link points to maintained SPEC | Use repository SPEC | A3 | Link selects Plus contract |
| 35 | Release examples avoid stale fixed versions | Corrected guidance; candidate execution separate | Explicit VERSION/TARGET placeholders | Select matching downloaded asset | A3/C | Documented asset command matches candidate release |
| 36 | Screenshot reflects actual UI status | Corrected guidance | Existing image retained and clearly labeled historical | Use running HTTP dashboard | A3 | No current-UI implication from old terminal image |
| 37 | Introduction and provider organization reflect product | Corrected guidance | Product-first root intro; Linear-specific onboarding label | Follow selected adapter guide | A3 | Attribution and feature organization accurate |

## Evidence and completion boundaries

The required command suite validates the development executable and fixture environment, and
reference comparison detects schema/flag drift even when README text is unchanged. It does not
prove every narrative sentence, external permission, cold installation, or release target.
Runtime repair rows link their acceptance suites above. Final independent review found no remaining
Important/Critical blocker after checking the queue checkpoint race, suspended scheduler reload,
repository identity casing, and retained launch-directory regressions. The full local gate on 2026-10-28 passed
537 tests with zero failures, six opt-in live tests skipped, 100% measured coverage, and clean lint
and Dialyzer. The first post-merge main run exposed an intermittent two-second test wait in the
handoff fixture. A controlled 2.2-second startup failure reproduces that deadline defect; the fixture
now uses a bounded 15-second monotonic deadline covering the helper's ten-second readiness budget
plus local promotion/rollback work. Runtime readiness and rollback policy are unchanged. This is
fixture evidence, not proof that arbitrary prose or every deployment is correct. External reports
must state date, source ref, environment, scenario, raw evidence link, outcome, and last successful
verification; missing credentials/capability remain unavailable. The `documentation-canary`
workflow runs weekly or by manual dispatch from trusted `main` only. It requires a separate private
fixture repository and an App installed there, identified by
`SYMPHONY_PLUS_CANARY_FIXTURE_KIND=dedicated-private-test` and
`SYMPHONY_PLUS_CANARY_REPOSITORY=owner/repo` repository variables. Dedicated App ID, installation ID,
PEM, and Codex `auth.json` are separate Actions secrets with the corresponding
`SYMPHONY_PLUS_CANARY_` names. Optional `SYMPHONY_PLUS_CANARY_REPAIR_REPOSITORY` enables App-backed,
deduplicated repair issues in an authorized work-intake repository with the `symphony-plus` dispatch
label (or `SYMPHONY_PLUS_CANARY_REPAIR_LABEL` when configured); absent permission is reported as
unavailable. The canary reads current-head checks/statuses, clones the private fixture with an
installation token, and executes one bounded read-only Codex turn in a temporary empty directory.
It never creates fixture issues or runs untrusted PR code. Missing capability fails the job and still
uploads the dated report. Scheduled checks can be delayed or disabled and are not continuous
availability evidence.

Milestone A remote rules have been applied and read back as recorded above. Milestone B adds
host-stamped independent-review provenance after normal registry ownership is verified. Milestone C
adds candidate artifact checks and controlled trusted external canaries. Report the completed scope,
platforms, actual source/candidate refs and CI links, failed/unavailable evidence, and remaining
repairs separately. The maintenance table is a closure guide, not evidence of completion by itself.
