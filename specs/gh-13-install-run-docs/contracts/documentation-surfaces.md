# Contract: Install and Run Documentation Surfaces

## Root README

- Contains an ordered source quick start that establishes the implementation directory.
- Names prerequisites and uses the supported `mise`-managed toolchain.
- Shows an explicit generic workflow path and observable startup result.
- Separates generic execution from GitHub App-authenticated orchestration.
- Links to the canonical generic, onboarding, workflow-control, and self-hosting guides.

## Elixir README

- Remains the canonical detailed source-install and generic-run reference.
- Keeps command spelling and order consistent with the root quick start.
- Explains explicit workflow arguments and the backward-compatible default.
- Keeps prebuilt releases distinct from source installation.
- Routes GitHub operators to App setup, `scripts/run-github`, and onboarding.

## Agent Guidance

- `elixir/AGENTS.md` supplies or links the correct directory, setup, build, validation, and launch commands.
- It routes GitHub onboarding to the agent runbook and GitHub execution to the safe launcher instead of encouraging credential handling in an issue workspace.

## Focused GitHub Guides

- `elixir/docs/agent-installation.md` remains the complete onboarding authority.
- `.symphony/README.md` remains this repository's concrete self-hosting authority.
- Both preserve host-side credentials, source-checkout startup, repository-owned workflow paths, and dedicated issue workspaces.

## Global Consistency Rules

- Every repository-relative link resolves.
- Every named checked-in script exists; generated launcher references are supported by the build.
- Duplicate fragments have no conflicting ordering, working directory, or launch mode.
- No snippet contains a literal secret or suggests copying credentials into tracked files, prompts, workspaces, issues, logs, commits, or pull requests.
- No documentation change alters runtime behavior, configuration semantics, release artifacts, or `SPEC.md`.
