# Symphony Plus

This directory contains this repository's Symphony Plus automation contract.

- `WORKFLOW.md` configures GitHub polling, isolated issue workspaces, Codex execution, and the
  repository-local Spec Kit lifecycle.
- `README.md` is the operator-facing guide and should be linked from the repository's root README.

Start Symphony Plus from its external installation, passing this repository's workflow explicitly:

```bash
./scripts/run-github \
  --app-profile PROJECT_PROFILE \
  /absolute/path/to/repository/.symphony/WORKFLOW.md \
  --port 4000
```

Customize this guide with the repository name, App profile, dashboard URL, workspace root, issue
commands, approval policy, restart recovery, and cleanup procedure. Never store App IDs, private
keys, installation tokens, or personal access tokens in this directory.
