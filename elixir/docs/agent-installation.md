# Install Symphony Plus in a Spec Kit repository

This runbook is written for an AI coding agent onboarding a GitHub repository to Symphony Plus.
Follow it in order. Treat every verification as a gate: do not continue after a failed gate, and do
not replace missing operator input with an assumption.

Symphony Plus itself is installed once outside target repositories. Each target repository owns
its `WORKFLOW.md`, GitHub label, App installation access, workspace root, and project-specific
commands. The official GitHub Spec Kit extension is not required and must not be installed as part
of this runbook.

## Responsibility and security contract

The agent performs repository inspection, installation, workflow customization, validation,
label creation, startup, and smoke-test observation. The operator alone performs these actions:

- create or select the private GitHub App in GitHub's web interface;
- generate and download its private key;
- approve installation or permission changes; and
- enter the App ID, installation ID, and local PEM path into the setup command.

Never ask the operator to paste a PEM, PAT, installation token, or private-key contents into chat.
Never place those values in a repository, issue workspace, process argument, log, issue, or pull
request. The local App profile is host configuration and must not be committed.

Do not overwrite an existing `WORKFLOW.md`, Spec Kit installation, workspace, or profile. Inspect
and reconcile it. Preserve unrelated changes, stop when a dirty tree makes the intended change
ambiguous, and use the target repository's normal branch and review process.

## 1. Establish installation values

Choose explicit values and retain them for the entire installation. Do not use a target repository
or developer checkout as the workspace root.

```bash
export TARGET_REPO="OWNER/REPOSITORY"
export TARGET_REPO_DIR="/absolute/path/to/target-repository"
export SYMPHONY_PLUS_DIR="/absolute/path/to/symphony-plus"
export SYMPHONY_WORKSPACE_ROOT="/absolute/path/to/symphony-workspaces/PROJECT"
export APP_PROFILE="project-name"
```

Record whether this is a new installation or a resume. A resume starts at the first failed or
incomplete gate; it does not repeat destructive or interactive work.

Verify the target and host tools:

```bash
git -C "$TARGET_REPO_DIR" status --short
git -C "$TARGET_REPO_DIR" remote -v
gh auth status
gh repo view "$TARGET_REPO" --json nameWithOwner,defaultBranchRef,viewerPermission
codex --version
git --version
```

Expected evidence:

- the target remote matches `TARGET_REPO`;
- the current changes are understood and do not overlap installation files;
- `viewerPermission` permits the required repository changes, and the operator separately confirms
  that they can create or manage the selected GitHub App;
- GitHub CLI, Codex CLI, and Git are available; and
- the default branch is known before creating an installation branch.

Stop if the repository identity or permissions are wrong.

## 2. Verify or install local Spec Kit

Symphony Plus invokes repository-local Spec Kit skills. An existing installation is authoritative:
do not reinitialize or upgrade it during Symphony Plus onboarding.

```bash
test -d "$TARGET_REPO_DIR/.specify"

for phase in specify clarify plan checklist tasks analyze implement converge; do
  test -r "$TARGET_REPO_DIR/.agents/skills/speckit-$phase/SKILL.md" || {
    echo "missing Spec Kit skill: speckit-$phase" >&2
    exit 1
  }
done
```

Also inspect the project constitution, templates, script variant, integration manifest, and any
`.specify/extensions.yml`. Report extensions; do not add the GitHub extension. Confirm that the
local skill instructions support `.specify/feature.json` or `SPECIFY_FEATURE_DIRECTORY`, because
concurrent issues use explicit `specs/gh-<issue>-<slug>` directories.

Treat the installed script variant as a host-runtime requirement, not only as repository metadata.
Identify the variant actually referenced by the installed skills and verify its interpreter before
starting Symphony:

```bash
if rg -q '\.specify/scripts/powershell/' "$TARGET_REPO_DIR/.agents/skills"; then
  command -v pwsh
  pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
elif rg -q '\.specify/scripts/bash/' "$TARGET_REPO_DIR/.agents/skills"; then
  command -v bash
  bash --version | head -n 1
else
  echo "unable to determine the Spec Kit script runtime from installed skills" >&2
  exit 1
fi
```

Stop if the referenced interpreter is absent. Install it using the platform vendor's supported
instructions, then rerun this gate. Do not start a smoke test expecting an issue agent to install
host software. For example, a PowerShell-variant installation on Linux requires `pwsh`; Windows
PowerShell on the mounted Windows path does not satisfy a Linux/WSL workflow unless `pwsh` itself is
available inside that Linux environment.

If Spec Kit is absent, stop and ask the operator to approve a version and initialization diff.
Then follow the official [Spec Kit installation guide](https://github.com/github/spec-kit/blob/main/docs/installation.md), pin an explicit release, and initialize Codex skills in a clean installation
branch. For the current Codex integration, the non-interactive shape is:

```bash
cd "$TARGET_REPO_DIR"
specify init --here --force --non-interactive \
  --integration codex \
  --integration-options="--skills" \
  --script sh
```

`--force` acknowledges changes to a non-empty repository. Use it only after preserving current
work and reviewing the expected merge. Review every generated change before committing it. Rerun
the local-skill verification above afterward.

## 3. Install or update Symphony Plus once

Keep Symphony Plus outside target repositories. One installation may operate multiple repositories
with separate processes, workflow files, ports, profiles, and workspace roots.

If `SYMPHONY_PLUS_DIR` does not exist:

```bash
git clone https://github.com/rohanyupadhyay/symphony-plus.git "$SYMPHONY_PLUS_DIR"
```

If it already exists, require a clean tree, inspect its remotes, and update its default branch with
a fast-forward-only pull. Do not discard local work or replace an official reference checkout.

Build and test the installed revision:

```bash
cd "$SYMPHONY_PLUS_DIR/elixir"
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
mise exec -- mix test
```

Expected evidence: `bin/symphony` exists and the tests finish with zero failures. Dependency audit
warnings must be reported separately; a successful build does not resolve them.

## 4. Create the repository-owned workflow

If the target has no `WORKFLOW.md`, copy the reusable template without modifying the template in
the Symphony Plus checkout:

```bash
cp "$SYMPHONY_PLUS_DIR/elixir/examples/github-speckit-WORKFLOW.md" \
  "$TARGET_REPO_DIR/WORKFLOW.md"
```

If the target already has `WORKFLOW.md`, compare it with the template and preserve repository
customizations. Do not replace it wholesale.

The target workflow must customize all of the following:

- `tracker.provider.repo`: exact `TARGET_REPO` value;
- `workspace.root`: exact dedicated `SYMPHONY_WORKSPACE_ROOT`;
- `hooks.after_create`: clone URL and deterministic dependency bootstrap;
- concurrency and turn limits appropriate for the host;
- project formatting, linting, typing, test, and build commands;
- branch naming `symphony/gh-<issue>-<slug>`;
- feature directory naming `specs/gh-<issue>-<slug>`;
- issue and pull-request wording appropriate for the repository; and
- the repository's merge policy, while retaining human-only merge.

Retain these security and lifecycle requirements:

- App environment references, never literal credentials;
- one persistent workspace and branch for the complete issue lifecycle;
- `danger-full-access` only inside the dedicated issue workspace tree;
- host-side `github_git_push`, never direct `git push` by the issue agent;
- spec, plan, and implementation approval checkpoints;
- bounded analyze and implement/converge remediation loops;
- review feedback routing back to the owning Spec Kit phase;
- no `speckit-taskstoissues`;
- no automatic merge; and
- no official GitHub Spec Kit extension.

Review the resulting YAML front matter and prompt as code. Confirm no placeholder remains:

```bash
rg -n 'OWNER/REPOSITORY|/absolute/path|PROJECT|TODO|TBD' "$TARGET_REPO_DIR/WORKFLOW.md"
git -C "$TARGET_REPO_DIR" diff --check
```

The `rg` command must return no unresolved template placeholder. Commit the target workflow and an
operator guide through the repository's normal review process. The workflow may be tested from a
local absolute path, but onboarding is not durable until those files are merged into the target's
default branch.

## 5. Create the dispatch label

Create or reconcile the one start label:

```bash
gh label create symphony \
  --repo "$TARGET_REPO" \
  --description "Ready for autonomous Symphony execution" \
  --color 1D76DB \
  --force

gh label list --repo "$TARGET_REPO" --search symphony
```

The label is the start switch. Do not add it to existing issues during installation. Removing it
stops future dispatch. Closing an issue makes it terminal and permits workspace cleanup.

## 6. Create or extend the private GitHub App

First check for an existing profile without reading or printing either profile file:

```bash
test -d "${XDG_CONFIG_HOME:-$HOME/.config}/symphony-plus/github-apps/$APP_PROFILE"
```

If no profile exists, give the operator this command to run in their own terminal:

```bash
cd "$SYMPHONY_PLUS_DIR/elixir"
./bin/symphony github-app setup "$TARGET_REPO" \
  --profile "$APP_PROFILE" \
  --name "UNIQUE PROJECT Symphony Plus"
```

The setup command opens a prefilled private-App registration page. The operator must create the
App, generate its private key, install it on the selected repository, and enter the requested data
directly into the terminal. GitHub App names are globally unique; replace the example with a
recognizable operator- or organization-owned name. Required repository permissions are:

- Contents: read and write;
- Issues: read and write;
- Pull requests: read and write;
- Workflows: read and write; and
- Metadata: read.

Webhooks remain disabled because Symphony Plus polls GitHub.

Profile creation is atomic. If verification fails, Symphony Plus removes its staged key copy and
does not create the named profile. Preserve the operator's original downloaded PEM, correct the
reported problem, and rerun the same command. If the App was already created and installed before
the failure, do not create another App: close the newly opened registration page and enter the
existing App and installation IDs and the original PEM path into the terminal.

If the profile already exists, the operator should add `TARGET_REPO` to that App installation's
repository selection. A single profile can be reused only when the App ID and installation ID are
the same. Use a new profile for a different installation ID.

After the operator reports completion, verify access:

```bash
cd "$SYMPHONY_PLUS_DIR/elixir"
./bin/symphony github-app verify "$TARGET_REPO" --profile "$APP_PROFILE"
```

Expected evidence: `Verified <app-slug>[bot] for OWNER/REPOSITORY.` Stop on any permission,
installation, identity, or file-mode error. Do not fall back to a personal PAT unless the operator
explicitly chooses legacy mode.

## 7. Start and recover Symphony Plus

Before replacing an existing process, record its workflow, port, PID, and current issue state.
Stop it cleanly and confirm the port is free. Never run two Symphony processes against the same
repository workflow and workspace root.

Start App mode from the Symphony Plus checkout:

```bash
cd "$SYMPHONY_PLUS_DIR/elixir"
./scripts/run-github \
  --app-profile "$APP_PROFILE" \
  "$TARGET_REPO_DIR/WORKFLOW.md" \
  --port 4000
```

Expected evidence:

- startup reports the workflow path and dashboard URL without credentials;
- `http://localhost:4000` responds;
- `/api/v1/state` reports tracker state; and
- every previously waiting issue is reconstructed from its latest authorized checkpoint without an
  immediate continuation turn.

For an existing human-authored checkpoint, preserve it. The next Symphony-authored marker should
come from the exact configured `<app-slug>[bot]` identity.

## 8. Run a disposable end-to-end smoke test

Do not use a production issue or an issue with deferred work. Create a dedicated issue whose only
purpose is reaching the first approval checkpoint:

```bash
SMOKE_URL=$(gh issue create \
  --repo "$TARGET_REPO" \
  --title "Symphony Plus installation smoke test" \
  --body "Exercise the installed Spec Kit workflow through specification approval only. Do not implement production behavior. This issue will be cancelled after checkpoint and restart-recovery verification.")
SMOKE_NUMBER=${SMOKE_URL##*/}

gh issue edit "$SMOKE_NUMBER" --repo "$TARGET_REPO" --add-label symphony
```

Record `SMOKE_NUMBER`. Poll the issue and dashboard without posting general comments. The first
successful pause must satisfy all of these conditions:

- a dedicated workspace exists below `SYMPHONY_WORKSPACE_ROOT`;
- the branch is `symphony/gh-<SMOKE_NUMBER>-<slug>`;
- the feature directory is `specs/gh-<SMOKE_NUMBER>-<slug>`;
- the branch exists on GitHub at the checkpoint SHA;
- the issue comment is authored by the exact configured App bot;
- the marker state is `awaiting_approval`, phase `specify`, gate `spec`; and
- the agent is no longer running while it waits.

Post `/symphony status` as an authorized human and confirm that the bot reports status and restores
the same checkpoint. Stop and restart Symphony Plus with the same command, then confirm the same
checkpoint is reconstructed without a duplicate agent run.

Finally post `/symphony cancel` as an authorized human. Confirm the bot removes the `symphony`
label and reports cancellation. Wait for the cancellation turn to finish, then close the issue.
Because the cancelled issue no longer has the dispatch label, ordinary active polling will not see
its later closed state. Stop and restart Symphony Plus with the same launch command; startup
terminal cleanup must remove the local smoke-test workspace without redispatching the issue. Do not
manually delete the workspace before verifying this recovery behavior. Do not merge the smoke
branch or its artifacts. Delete the remote smoke branch only with explicit operator approval.

## 9. Completion report

Report concrete evidence, not only commands attempted:

- Symphony Plus revision and installation path;
- target repository and committed workflow revision;
- Spec Kit version, integration, required skills, and extension status;
- App bot login, profile name, and successful repository verification, but no IDs or paths;
- label configuration;
- dashboard reachability;
- recovered existing checkpoint state;
- smoke issue number, checkpoint SHA, status/restart/cancel results, and cleanup result;
- test commands and results;
- unresolved dependency advisories or pre-existing target failures; and
- every deferred component, including webhooks, daemon startup, remote-worker secret brokering, and
  the official GitHub Spec Kit extension.

Installation is complete only when the smoke test and restart recovery pass. A successful build or
successful App verification alone is not completion.

## Agent handoff prompt

An operator can give an AI coding agent this prompt:

> Install Symphony Plus for `<OWNER/REPOSITORY>` by following
> `elixir/docs/agent-installation.md` from the Symphony Plus repository. Preserve any existing
> Spec Kit installation and repository changes. Perform every agent-owned step and verification,
> pause for the documented human-only GitHub App actions without requesting secret contents, and
> iterate on the runbook or implementation whenever the VerityCX-style acceptance test exposes a
> gap. Do not declare completion until the disposable smoke issue passes checkpoint, status,
> restart-recovery, cancellation, closure, and workspace-cleanup checks.
