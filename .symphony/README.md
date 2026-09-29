# Symphony Plus Self-Hosting

GitHub Issues are the control plane for updating Symphony Plus with Symphony Plus. The local
dashboard shows agent state, logs, retries, and token usage; requirements and approvals remain in
GitHub issue comments.

## Start the service

The `veritycx` profile is an operator-owned local GitHub App profile already installed for
`rohanyupadhyay/symphony-plus`. It is stored outside this repository and MUST NOT be copied into an
issue, log, commit, or pull request.

From the source checkout:

```bash
cd /home/rohan/code/symphony-plus/elixir
mise exec -- mix setup
mise exec -- mix build
./bin/symphony github-app verify rohanyupadhyay/symphony-plus --profile veritycx
./scripts/run-github \
  --app-profile veritycx \
  /home/rohan/code/symphony-plus/.symphony/WORKFLOW.md \
  --port 4001
```

Open `http://localhost:4001` for runtime status. Startup is intentionally manual; no systemd or
automatic reboot service is configured. Port 4000 remains reserved for the VerityCX instance.

The service uses `/home/rohan/code/symphony-workspaces/symphony-plus`, never this checkout, for
issue workspaces. Do not run a second process with the same workflow and workspace root.

## Dispatch and control work

- Open without `symphony`: ignored.
- Open with `symphony`: authorized to run or waiting at a checkpoint.
- Remove `symphony`: stop or cancel future dispatch.
- Closed: terminal; startup reconciliation removes its workspace.

Use these commands at approval and recovery checkpoints:

```text
/symphony approve spec
/symphony approve plan
/symphony approve implementation
/symphony revise [spec|plan|implementation] <instructions>
/symphony retry
/symphony status
/symphony cancel
```

Each issue keeps one `symphony/gh-<number>-<slug>` branch and one
`specs/gh-<number>-<slug>` directory through the complete Spec Kit lifecycle. Symphony never
merges automatically. Human review and merge are mandatory.

## Security and recovery

The launcher supplies App identifiers and the private-key path only to the Symphony host. It mints
short-lived installation tokens and removes App credentials from Codex. Agents commit locally and
push only through the host-authenticated `github_git_push` tool.

`danger-full-access` is trusted-host execution, not filesystem confinement. The launcher validates
that each agent starts in its dedicated issue workspace, but a process running as the operator can
still access files allowed to that account. Keep unrelated credentials out of the operator's
environment and filesystem wherever practical; environment scrubbing alone is not a security
boundary.

Questions, approvals, status, and review cursors are stored in hidden markers in ordinary GitHub
comments. Restarting the process reconstructs waiting work without a workflow database. The
integration polls every 30 seconds; it does not use webhooks.

The workflow uses the repository-local Spec Kit v1.0.12 skills and project constitution. It does
not install the official GitHub extension or turn `tasks.md` entries into child issues.

## Installation smoke test

After the setup pull request is merged, create one disposable issue whose only purpose is reaching
the specification approval checkpoint. Add `symphony`, verify its branch, feature directory,
checkpoint SHA, and App-bot comment, then exercise `/symphony status`, restart recovery, and
`/symphony cancel`. Close the issue and restart once more to verify workspace cleanup. Do not use a
real feature or deferred issue for this smoke test.
