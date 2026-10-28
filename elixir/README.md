# Symphony Plus Elixir

## Automatic source updates

Set `updates.enabled: true` only for the canonical source checkout. `installation_root` must be an
absolute Git checkout outside `workspace.root`; `remote` defaults to `origin`; `interval_ms` must be
positive. `prepare_command` runs in the candidate's `elixir/` directory and must produce executable
`bin/symphony-plus`. After the old BEAM exits, activation installs that executable and starts
`launcher_command` from the canonical `elixir/` directory. The CLI restores the original service
working directory and arguments and signals readiness only after successful startup. A failed startup restores and starts
the prior executable with those arguments. A GitHub launcher also retains its host App profile.
Keep a supervisor responsible for subsequent service failures; a readiness check is not a perpetual
availability guarantee.

JSON and LiveView observability use one runtime-status projection. The legacy terminal dashboard
is disabled during normal service startup; use the HTTP operations dashboard. Recoverable quota
pauses appear as quota-waiting, while input/approval pauses and failed native quota resumes appear
as blocked with concise diagnostic context.

This directory contains the current Elixir/OTP implementation of Symphony Plus, based on
[`SPEC.md`](../SPEC.md) at the repository root.

> [!WARNING]
> Symphony Plus Elixir is prototype software intended for evaluation only and is presented as-is.
> We recommend implementing your own hardened version based on `SPEC.md`.

## Historical screenshot

This image shows an earlier terminal UI and branding; it does not represent the current HTTP dashboard.

![Historical terminal screenshot](../.github/media/elixir-screenshot.png)

## How it works

1. Polls the configured tracker for candidate work (included adapters: Linear, GitHub Issues, Jira
   Cloud, Asana, and GitLab)
2. Creates a workspace per issue
3. Launches Codex in [App Server mode](https://developers.openai.com/codex/app-server/) inside the
   workspace
4. Sends a workflow prompt to Codex
5. Keeps Codex working on the issue until the work is done

During app-server sessions, the selected tracker adapter may advertise provider-native tools. The
Linear serves `linear_graphql`, GitHub Issues serves `github_api` and, for local GitHub App
workspaces, `github_git_push`, Jira Cloud serves
`jira_rest`, Asana serves `asana_api`, and GitLab serves `gitlab_api`. Symphony Plus executes those
tools with configured host-side auth and removes declared tracker-token environment variables from
the Codex child, so the agent does not need a second tracker login.

If a claimed issue moves to a configured `tracker.terminal_states` state (Linear defaults include
`Done`, `Closed`, `Canceled`, `Cancelled`, and `Duplicate`),
Symphony Plus stops the active agent for that issue and cleans up matching workspaces.

With `codex.approval_policy: never`, command/file approvals and recognized MCP approval questions
are approved automatically. Other unresolved input/approval requests keep the
issue claimed and exposes it as blocked in the runtime state, JSON API, and dashboard. Blocked
entries are in memory only; restarting the orchestrator clears that blocked map, so any still-active
tracker issue can become a dispatch candidate again after restart.

Recognized Codex quota exhaustion follows a separate recovery path. Symphony Plus persists a non-secret
quota-wait record under `<workspace-root>/.symphony-plus/quota-waits/`, releases the worker slot without
incrementing failure retries, and resumes the saved native thread after its validated renewal time.
When Codex omits a valid renewal time, `quota.unknown_recheck_ms` controls the bounded recheck
interval (default: 300000 ms). Native resume failure is operator-blocking; Symphony Plus never starts a
fresh thread as an automatic fallback. See [Quota waits and native resume](docs/quota-resume.md).

## Linear onboarding

1. Make sure your codebase is set up to work well with agents: see
   [Harness engineering](https://openai.com/index/harness-engineering/).
2. Get a new personal token in Linear via Settings → Security & access → Personal API keys, and
   set it as the `LINEAR_API_KEY` environment variable.
3. Copy this directory's `WORKFLOW.md` to your repo.
4. Optionally copy the `commit`, `push`, `pull`, `land`, and `linear` skills to your repo.
   - The `linear` skill expects Symphony Plus's `linear_graphql` app-server tool for raw Linear GraphQL
     operations such as comment editing or upload flows.
5. Customize the copied `WORKFLOW.md` file for your project.
   - To get your project's slug, right-click the project and copy its URL. The slug is part of the
     URL.
   - When creating a workflow based on this repo, note that it depends on non-standard Linear
     issue statuses: "Rework", "Human Review", and "Merging". You can customize them in
     Team Settings → Workflow in Linear.
6. Follow the instructions below to install the required runtime dependencies and start the service.

## Prerequisites

Source installation requires Bash, Git, the Codex CLI, and
[mise](https://mise.jdx.dev/) to install the repository's supported Elixir/Erlang versions.
Run these commands from the `elixir/` directory of a Symphony Plus source checkout unless a
command explicitly changes directory.

```bash
mise install
mise exec -- elixir --version
```

## Install and run from source

From the directory where you want the installation checkout:

<!-- docs:scenario cold-source-install -->
```bash
git clone https://github.com/rohanyupadhyay/symphony-plus
cd symphony-plus/elixir
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
```

`mix build` produces the development escript. In a terminal with the pinned Erlang runtime on
PATH (for example `mise exec -- bash`), define your installation inputs. Use an absolute data
root for each separately running service; different ports alone do not isolate registrations.
Only one active GitHub project can own a repository's queue in an installation. A duplicate
repository workflow remains registered but unavailable until the existing owner is removed.
These variables are operator inputs, not application environment settings:

```bash
export SYMPHONY_PLUS_BIN="$PWD/bin/symphony-plus"
export SYMPHONY_PLUS_DATA_ROOT="$HOME/.local/share/symphony-plus/main"
export SYMPHONY_PLUS_LOGS_ROOT="$HOME/.local/state/symphony-plus/main/log"
export SYMPHONY_PLUS_PORT=4000
export SYMPHONY_PLUS_SERVICE_URL="http://127.0.0.1:$SYMPHONY_PLUS_PORT"
export SYMPHONY_PLUS_WORKFLOW="/absolute/target-repository/.symphony-plus/WORKFLOW.md"
```

Start an empty registry first. It needs no tracker or Codex credentials while no projects exist:

<!-- docs:scenario service-start -->
```bash
"$SYMPHONY_PLUS_BIN" --i-understand-that-this-will-be-running-without-the-usual-guardrails \
  --port "$SYMPHONY_PLUS_PORT" \
  --data-root "$SYMPHONY_PLUS_DATA_ROOT" \
  --logs-root "$SYMPHONY_PLUS_LOGS_ROOT"
```

Open the service URL. In another terminal with the same input variables, register the actual
customized target workflow. Before registering live work, configure the selected tracker,
authenticate Codex, and review the workflow's hooks and dispatch filters. The bundled Linear
workflow is an example and is never selected implicitly.

<!-- docs:scenario project-add -->
```bash
"$SYMPHONY_PLUS_BIN" projects add "$SYMPHONY_PLUS_WORKFLOW" \
  --service-url "$SYMPHONY_PLUS_SERVICE_URL"
```

List durable registrations from any working directory, including while the service is stopped:

<!-- docs:scenario project-list -->
```bash
"$SYMPHONY_PLUS_BIN" projects list --data-root "$SYMPHONY_PLUS_DATA_ROOT"
```

Copy the generated id from add/list into `SYMPHONY_PLUS_PROJECT_ID`. Removal requires an idle
project and preserves its workspace files:

<!-- docs:scenario project-remove -->
```bash
"$SYMPHONY_PLUS_BIN" projects remove "$SYMPHONY_PLUS_PROJECT_ID" \
  --service-url "$SYMPHONY_PLUS_SERVICE_URL"
```

Registrations store only the generated id and canonical workflow path. Restart with the same
absolute data root to restore them. Missing/temporarily invalid registered workflows are displayed
as unavailable and retried after repair. Default data location is cwd-relative
`tmp/symphony-plus/projects.json`; explicit `--data-root` avoids accidentally selecting a different
installation when cwd changes. The positional workflow argument registers that explicit workflow
in addition to existing registrations; it does not select an exclusive single-project mode.

GitHub orchestration requires an operator-owned App profile and the credential-scrubbing
`scripts/run-github` launcher. Follow the [AI-agent installation runbook](docs/agent-installation.md),
which preserves the same explicit data-root and service-address requirements.

## Burrito releases

Symphony Plus ships self-contained executables built with
[Burrito](https://github.com/burrito-elixir/burrito). They embed Erlang/OTP, Elixir, and Symphony Plus,
but local issue execution still requires Bash, `codex`, `git`, and the selected tracker credentials.

Supported release targets:

- `macos_arm64`
- `macos_x86_64`
- `linux_arm64`
- `linux_x86_64`

`v*` tags publish all four targets with checksums. A manual workflow run builds the same
artifacts without creating a release.

The `burrito-nightly` workflow builds each push to `main`, with no scheduled rebuilds.
After all four platform smoke tests pass, it updates the rolling
[`nightly` prerelease](https://github.com/rohanyupadhyay/symphony-plus/releases/tag/nightly),
including binaries and checksums. Nightly binaries use a `-nightly` version suffix;
the release notes identify the source commit. Stable releases remain unchanged.
For a stable tag `vX.Y.Z`, use `https://github.com/rohanyupadhyay/symphony-plus/releases/tag/vX.Y.Z`
and select the asset named `symphony-plus-vX.Y.Z-TARGET` plus its `.sha256` file. For nightly,
select `symphony-plus-nightly-TARGET` from the linked prerelease. The release workflow verifies
the exact asset name, checksum, documented launch command, HTTP readiness, and empty project list
on all four targets before publication.

After downloading the executable for your platform from a release, set these inputs to the
downloaded asset name, an unused local port, and an installation-specific data root:

```bash
# Replace VERSION and TARGET with the downloaded release's version and platform.
export SYMPHONY_PLUS_BIN="$PWD/symphony-plus-VERSION-TARGET"
export SYMPHONY_PLUS_PORT=4000
export SYMPHONY_PLUS_DATA_ROOT="$HOME/.local/share/symphony-plus/main"
chmod +x "$SYMPHONY_PLUS_BIN"
```

Start the empty installation; it requires no tracker or Codex credentials:

<!-- docs:scenario release-service-start -->
```bash
"$SYMPHONY_PLUS_BIN" --i-understand-that-this-will-be-running-without-the-usual-guardrails \
  --port "$SYMPHONY_PLUS_PORT" --data-root "$SYMPHONY_PLUS_DATA_ROOT"
```

## Configuration

Pass a custom workflow file path to `./bin/symphony-plus` when starting the service:

```bash
./bin/symphony-plus --i-understand-that-this-will-be-running-without-the-usual-guardrails \
  --port 4000 --data-root /absolute/installation/data /absolute/target-repository/WORKFLOW.md
```

If no path is passed, Symphony Plus starts/restores the installation registry without implicitly
registering `./WORKFLOW.md`.

Optional flags:

- `--logs-root` tells Symphony Plus to write logs under a different directory (default: `./log`)
- `--data-root` selects installation-local durable registry data (default: cwd-relative `tmp/symphony-plus`)
- `--port` starts the Phoenix observability service; omit it for no HTTP listener unless a
  restored project config supplies `server.port`. Choose an explicit port for operator access.

The `WORKFLOW.md` file uses YAML front matter for configuration, plus a Markdown body used as the
Codex session prompt.

Minimal example:

```md
---
tracker:
  kind: linear
  provider:
    project_slug: "..."
workspace:
  root: ~/code/workspaces
hooks:
  after_create: |
    git clone git@github.com:your-org/your-repo.git .
agent:
  max_concurrent_agents: 10
  max_turns: 20
codex:
  command: codex app-server
---

You are working on an issue from the configured tracker {{ issue.identifier }}.

Title: {{ issue.title }} Body: {{ issue.description }}
```

Notes:

- Optional values use defaults; adapter-required settings must still be supplied. See the
  [generated configuration and CLI reference](docs/configuration-reference.md) for raw defaults.
- `tracker.kind` selects an adapter. Adapter-owned endpoint, scope, and auth settings belong under
  `tracker.provider`; the current Linear adapter still accepts the older flat `endpoint`,
  `api_key`, `project_slug`, and `assignee` aliases for compatibility.
- `tracker.required_labels` is optional. When set, an issue must have every
  configured label to dispatch or continue running. Label matching ignores
  case and surrounding whitespace. A blank configured label matches no issue.
- Safer Codex defaults are used when policy fields are omitted:
  - `codex.approval_policy` defaults to `{"reject":{"sandbox_approval":true,"rules":true,"mcp_elicitations":true}}`
  - `codex.thread_sandbox` defaults to `workspace-write`
  - `codex.turn_sandbox_policy` defaults to a `workspaceWrite` policy rooted at the current issue workspace
- `codex.turn_timeout_ms` is the maximum silence interval while a turn is streaming. Each
  app-server update resets it; it is not a total turn runtime cap.
- `codex.stall_timeout_ms` is a separate scheduler watchdog for silent workers (default: `300000`
  ms). Set it to `0` to disable that watchdog. Raising turn timeout alone does not disable it.
- Supported `codex.approval_policy` values depend on the targeted Codex app-server version. In the current local Codex schema, string values include `untrusted`, `on-failure`, `on-request`, and `never`, and object-form `reject` is also supported.
- Supported `codex.thread_sandbox` values: `read-only`, `workspace-write`, `danger-full-access`.
- When `codex.turn_sandbox_policy` is set explicitly, Symphony Plus passes the map through to Codex
  unchanged. Compatibility then depends on the targeted Codex app-server version rather than local
  Symphony Plus validation.
- Workflows that run package managers or other commands that resolve external hosts should set
  `networkAccess: true` in `codex.turn_sandbox_policy`; otherwise DNS/network access may be denied
  by the Codex turn sandbox.
- Workflows whose agents must create branches or commits cannot use `workspaceWrite`: Codex makes
  `.git` read-only in that sandbox. Use `danger-full-access`/`dangerFullAccess` only with a
  dedicated per-issue workspace root, as demonstrated by `examples/github-speckit-WORKFLOW.md`.
- `agent.max_turns` caps how many back-to-back Codex turns Symphony Plus will run in a single agent
  invocation when a turn completes normally but the issue is still in an active state. Default: `20`.
- If the Markdown body is blank, Symphony Plus uses a default prompt template that includes the issue
  identifier, title, and body.
- Hooks are trusted host execution: they inherit the host environment, including credential
  references, before Codex-child scrubbing. Review all hook code and code it invokes.
- Use `hooks.after_create` to bootstrap a fresh workspace. For a Git-backed repo, you can run
  `git clone ... .` there, along with any other setup commands you need.
- If a hook needs `mise exec` inside a freshly cloned workspace, trust the repo config and fetch
  the project dependencies in `hooks.after_create` before invoking `mise` later from other hooks.
- For the Linear adapter, `tracker.provider.api_key` reads from `LINEAR_API_KEY` when unset or
  when value is `$LINEAR_API_KEY`. The legacy flat `tracker.api_key` alias behaves the same way.
- Do not put a literal tracker token in a repo-owned `WORKFLOW.md` if Codex can read that
  workspace. Use `$VAR`/host-side secret references so Symphony Plus can keep the token out of the
  child environment.
- For path values, `~` expands to the home directory. Relative local workspace roots resolve
  against the registered workflow directory. Prefer absolute paths for operational clarity.
- For env-backed path values, use `$VAR`. `workspace.root` resolves `$VAR` before path handling,
  while `codex.command` stays a shell command string and any `$VAR` expansion there happens in the
  launched shell.

```yaml
tracker:
  provider:
    api_key: $LINEAR_API_KEY
workspace:
  root: $SYMPHONY_PLUS_WORKSPACE_ROOT
hooks:
  after_create: |
    git clone --depth 1 "$SOURCE_REPO_URL" .
codex:
  command: "$CODEX_BIN --config 'model=\"gpt-5.5\"' app-server"
```

- A missing/invalid registered workflow is unavailable while the installation service remains
  running; its registration is retained for repair. An explicitly supplied missing positional
  workflow is rejected.
- If a later reload fails, Symphony Plus keeps running with the last known good workflow and logs the
  reload error until the file is fixed.
- CLI `--port` selects the installation's Phoenix LiveView dashboard and JSON API at
  `/`, `/api/v1/state`, `/api/v1/<issue_identifier>`, and `/api/v1/refresh`.
  State rows include `project_id`. When multiple projects have the same issue identifier,
  use `/api/v1/<issue_identifier>?project_id=<id>`; an ambiguous unqualified lookup returns HTTP 409.
  A startup workflow can supply `server.port` before the endpoint starts; a subsequently registered
  project's `server.port` does not rebind the installation endpoint. Prefer explicit `--port`.

### Linear adapter profile

- Config: use `tracker.kind: linear` with `tracker.provider.endpoint` (default
  `https://api.linear.app/graphql`), `api_key` (defaults to `LINEAR_API_KEY` and accepts
  `$VAR`), required `project_slug`, and optional `assignee` (a Linear user ID or `me`,
  defaulting to `LINEAR_ASSIGNEE`).
  The legacy flat `tracker.endpoint`, `api_key`, `project_slug`, and `assignee` aliases remain
  supported. `required_labels`, `active_states`, and `terminal_states` stay under `tracker`.
- Scope and paging: candidate reads filter the configured project slug and requested state names,
  following Linear pages of 50. ID refreshes are also project-scoped and batch up to 50 IDs. Empty
  state/ID lists return `{:ok, []}` without a Linear request.
- Identity and normalization: `issue.id` is the Linear issue ID and `issue.native_ref` is currently
  `nil`. Records missing a nonblank ID, identifier, title, or state are dropped from candidate
  pages and fail ID refreshes. State keeps Linear's spelling; integer priorities are preserved and
  other priority values become `nil`; RFC 3339 timestamps are parsed and unusable timestamps become
  `nil`. Labels are trimmed, lowercased, deduplicated, and blanks are dropped; blockers come from
  inverse `blocks` relations.
- Dispatchability: the adapter marks an issue dispatchable only when optional assignee routing
  matches and a `Todo` issue has no non-terminal blocker. The generic scheduler then applies
  active/terminal states, required labels, claims, retries, and concurrency.
- Tool: the Linear adapter advertises `linear_graphql`, accepting either a raw query string or an
  object with nonblank `query` and optional object `variables`. Symphony Plus executes it host-side
  with the session-bound endpoint/token and strips declared token environment variables from the
  Codex child. `project_slug` scopes scheduler reads, not raw tool calls; the tool can access
  whatever the configured Linear token can access.
- Responsibility and errors: `linear_graphql` adds no idempotency key, retry, scope guard, or
  rate-limit policy, so workflows own idempotent mutations and handling provider errors. Read/config
  failures use `{:error, :missing_linear_api_token}`, `{:error, :missing_linear_project_slug}`,
  `{:error, :invalid_linear_endpoint}`, `{:error, :invalid_linear_assignee}`,
  `{:error, :missing_linear_viewer_identity}`, `{:error, {:linear_api_status, status}}`,
  `{:error, {:linear_api_request, reason}}`, `{:error, {:linear_graphql_errors, errors}}`,
  `{:error, :linear_unknown_payload}`, or `{:error, :linear_missing_end_cursor}`. Tool results
  are maps with `"success"`, JSON-string `"output"`, and text `"contentItems"`; invalid
  arguments, missing auth, and transport failures return `"success" => false` with
  `{"error": {"message": ...}}`, while top-level GraphQL errors preserve the response body with
  `"success" => false`.
  For portable reporting, map missing/invalid token, project, endpoint, assignee, or viewer errors
  to `tracker_config` or `tracker_auth`, request failures to `tracker_transport`, non-200 responses to
  `tracker_response` (`429` is `tracker_rate_limited`), GraphQL/unknown payload failures to
  `tracker_payload`, and missing cursors to `tracker_pagination`; logs and tool responses carry the
  human-readable provider detail.

### GitHub Issues adapter

- Config: use `tracker.kind: github` with required `tracker.provider.repo` in `owner/repo` form,
  App-first `tracker.provider.auth` containing `kind: github_app`, `app_id`, `installation_id`, and
  `private_key_path`, and optional `api_url` (default `https://api.github.com`, HTTPS only).
  Legacy `token` remains supported, defaults to `GITHUB_TOKEN`, and accepts `$VAR`. Set explicit
  `active_states` and `terminal_states`; active entries may be `open` and terminal entries may be
  `closed`.
- Reads and identity: polling is scoped to the configured repository; `issue.id` is the
  repository issue number, `issue.identifier` is `GH-<number>`, hidden or deleted `404` issues are
  omitted on refresh, and pull requests returned by the Issues API are not dispatchable.
- Tool and auth: `github_api` accepts a relative REST `path` plus optional `params` and JSON
  `body`; Symphony Plus executes it host-side with the session-bound token. `github_git_push` accepts
  only the current issue branch and exact local head SHA, rejects dirty/mismatched workspaces, and
  uses a short-lived installation token without placing it in the Codex environment or tool
  response. App-authenticated Git pushes are initially local-workspace only. Symphony Plus removes all
  configured GitHub credential variables from the Codex child.
- Private bootstrap: set `tracker.provider.bootstrap_clone: true` with GitHub App auth to have
  the host clone the configured repository using a short-lived installation token before
  `hooks.after_create`. The token is not passed to the hook or Codex child. Keep the hook for
  repository setup after cloning; a plain HTTPS clone cannot access a private repository.
- Optional workflow control: `tracker.provider.workflow_control.enabled: true` makes versioned
  issue comments a restart-safe pause/resume mechanism. The `github_workflow_checkpoint` tool
  posts checkpoints for the current issue, and only configured GitHub author associations can
  supply answers or commands. A managed PR can use `review_pending` to validate its same-repository
  branch/head, inherit the required label, and automatically resume the originating issue workspace
  with complete current-head review/check context. Successful automatic review admits the managed
  PR to the merge queue without human approval; a human change request suspends all mutations until
  dismissal, then processing resumes automatically.
  New commits on the managed branch trigger review of the current head. Merge conflicts and
  PR-caused check failures automatically return to the issue agent for repair and review.
  See [the workflow-control guide](docs/github-workflow-control.md)
  and the [reusable Spec Kit template](examples/github-speckit-WORKFLOW.md).

#### Serialized merge queue

Set `merge_queue.enabled: true` to enable serialized final integration. Admissions are keyed by PR
number and exact automatically reviewed head SHA. Only the active head is updated against the latest target;
checks and eligibility are re-read on the resulting SHA before a conditional merge. Non-head PRs
are never updated by queue polling.

```yaml
merge_queue:
  enabled: true
  poll_interval_ms: 30000
  max_retry_backoff_ms: 300000
```

See [the merge-queue guide](docs/github-merge-queue.md) for dependencies, outcomes, and recovery.

For repository-local GitHub/Spec Kit automation, keep the executable workflow and operator guide
under the tool-owned `.symphony-plus/` directory:

```text
.symphony-plus/
├── README.md
└── WORKFLOW.md
```

Link `.symphony-plus/README.md` from the repository's root README for contributor discoverability. The
AI-agent installation runbook creates this layout; generic Symphony Plus workflows may still use any
explicit path, and the backward-compatible CLI default remains `./WORKFLOW.md`.

Create and verify an operator-owned GitHub App profile, then start an App-authenticated workflow:

```bash
./bin/symphony-plus github-app setup owner/repository --profile default
./bin/symphony-plus github-app verify owner/repository --profile default
./scripts/run-github --app-profile default /absolute/path/to/repository/.symphony-plus/WORKFLOW.md --port 4000
```

The profile lives under `${XDG_CONFIG_HOME:-~/.config}/symphony-plus/github-apps/<profile>` with a
private `profile.json` and `private-key.pem`. One profile may be reused for repositories covered by
the same GitHub App installation. See the workflow-control guide for permissions, rotation, and
PAT fallback.

For a complete new-repository procedure designed to be executed and verified by an AI coding
agent, follow the [agent installation runbook](docs/agent-installation.md).

### Jira Cloud adapter

- Config: use `tracker.kind: jira` with provider `base_url`, `email`, `api_token`, and required
  `project_key`; the first three default to `JIRA_BASE_URL`, `JIRA_EMAIL`, and `JIRA_API_TOKEN`
  and accept `$VAR`. Set explicit Jira-native `active_states` and `terminal_states`.
- Issues and reads: candidate reads filter the configured project and requested statuses.
  ID refreshes filter requested IDs and project, including terminal transitions outside active statuses; `issue.id` is Jira's immutable ID and `issue.identifier` is the issue key.
- Blockers: inward `Blocks` links populate `blocked_by`; issues in Jira's `new` status category
  wait until blockers reach configured terminal states, while in-progress categories keep running.
- Tool: `jira_rest` sends relative `/rest/api/3/` requests host-side with configured Basic auth,
  strips token environment variables from Codex, and can reach whatever the Jira credential can.

### Asana adapter

- Config: use `tracker.kind: asana` with required `tracker.provider.project_gid`, optional
  `endpoint` (default `https://app.asana.com/api/1.0`), and `api_key` (defaults to `ASANA_PAT` and
  accepts `$VAR`). Both `tracker.active_states` and `tracker.terminal_states` must be
  explicitly configured with project section names; Linear defaults do not apply.
- Scope: Symphony Plus polls tasks in the configured project, treats their section as state, and omits
  deleted or out-of-project tasks during ID refreshes. Tasks must have an actual named section;
  only incomplete tasks in a configured active section are eligible.
- Tool: `asana_api` sends relative Asana REST requests host-side with the configured auth; Symphony Plus
  strips `ASANA_PAT` and configured token variables from the Codex child, while raw tool calls are
  not limited to the configured project.

### GitLab adapter

- Configure `tracker.kind: gitlab` with `tracker.provider.project_path`, optional `api_url`, and
  `api_key` (default `GITLAB_PAT`). Explicitly set both `tracker.active_states: [opened]`
  and `tracker.terminal_states: [closed]`; Linear defaults do not apply.
- Symphony Plus reads project issues by IID and exposes route-safe `GL-<iid>` identifiers.
- `gitlab_api` forwards raw GitLab REST requests with host-side auth and keeps configured tracker
  credentials and provider authentication aliases out of the Codex child.

## Web dashboard

The observability UI now runs on a minimal Phoenix stack:

- LiveView for the dashboard at `/`
- JSON API for operational debugging under `/api/v1/*`
- Bandit as the HTTP server
- Phoenix dependency static assets for the LiveView client bootstrap
- Tracker issue identifiers link to the tracker-provided URL when it uses `http` or `https`

## Project Layout

- `lib/`: application code and Mix tasks
- `test/`: ExUnit coverage for runtime behavior
- `WORKFLOW.md`: in-repo workflow contract used by local runs
- `../.codex/`: repository-local Codex skills and setup helpers

## Testing

```bash
make all
```

Every provider live suite requires a physical `${CODEX_HOME:-~/.codex}/auth.json` file, including
local tests. A keychain-only or API-key-only login does not satisfy that harness prerequisite.
Commands below start in this `elixir/` directory with the pinned runtime on PATH.

Run the real external end-to-end test only when you want Symphony Plus to create disposable Linear
resources and launch a real `codex app-server` session:

```bash
export LINEAR_API_KEY=...
make e2e
```

Optional environment variables:

- `SYMPHONY_PLUS_LIVE_LINEAR_TEAM_KEY` defaults to `SYME2E`
- `SYMPHONY_PLUS_LIVE_SSH_WORKER_HOSTS` uses those SSH hosts when set, as a comma-separated list

`make e2e` runs two live scenarios:
- one with a local worker
- one with SSH workers

If `SYMPHONY_PLUS_LIVE_SSH_WORKER_HOSTS` is unset, the SSH scenario uses `docker compose` to start two
disposable SSH workers on `localhost:<port>`. The live test generates a temporary SSH keypair,
mounts the host `~/.codex/auth.json` into each worker, verifies that Symphony Plus can talk to them
over real SSH, then runs the same orchestration flow against those worker addresses. This keeps
the transport representative without depending on long-lived external machines.

Set `SYMPHONY_PLUS_LIVE_SSH_WORKER_HOSTS` if you want `make e2e` to target real SSH hosts instead.

The live test creates a temporary Linear project and issue, writes a temporary `WORKFLOW.md`, runs
a real agent turn, verifies the workspace side effect, requires Codex to comment on and close the
Linear issue, then marks the project completed so the run remains visible in Linear.

Run the opt-in GitHub Issues live test with a disposable/scratch repository:

```bash
export SYMPHONY_PLUS_LIVE_GITHUB_REPO=owner/scratch-repo
export GITHUB_TOKEN=...
SYMPHONY_PLUS_RUN_GITHUB_LIVE_E2E=1 mix test test/symphony_plus/github_live_e2e_test.exs
```

Run the opt-in Jira Cloud live test against a disposable project whose credential can browse,
create, comment on, transition, and delete issues:

```bash
export JIRA_BASE_URL=https://your-site.atlassian.net
export JIRA_EMAIL=...
export JIRA_API_TOKEN=...
export SYMPHONY_PLUS_LIVE_JIRA_PROJECT_KEY=TEST
SYMPHONY_PLUS_RUN_JIRA_LIVE_E2E=1 mix test test/symphony_plus/jira_live_e2e_test.exs
```

Run the opt-in Asana live E2E against disposable Asana resources:

```bash
export ASANA_PAT=...
export SYMPHONY_PLUS_LIVE_ASANA_WORKSPACE_GID=...
# Required only when the workspace is an organization:
# export SYMPHONY_PLUS_LIVE_ASANA_TEAM_GID=...
SYMPHONY_PLUS_RUN_ASANA_LIVE_E2E=1 mix test test/symphony_plus/asana_live_e2e_test.exs
```

Run the opt-in GitLab live E2E against a disposable project:

```bash
export GITLAB_PAT=...
export SYMPHONY_PLUS_LIVE_GITLAB_PROJECT_ID=...
SYMPHONY_PLUS_RUN_GITLAB_LIVE_E2E=1 mix test test/symphony_plus/gitlab_live_e2e_test.exs
```

## FAQ

### Why Elixir?

Elixir is built on Erlang/BEAM/OTP, which is great for supervising long-running processes. It has an
active ecosystem of tools and libraries. It also supports hot code reloading without stopping
actively running subagents, which is very useful during development.

### What's the easiest way to set this up for my own codebase?

Launch `codex` in your repo, give it the URL to the Symphony Plus repo, and ask it to set things up for
you.

## License

This project is licensed under the [Apache License 2.0](../LICENSE).
