# Quickstart Validation: Install and Run Documentation

## Prerequisites

- Work from the issue branch in its isolated workspace.
- Do not use real GitHub App credentials or start production orchestration.
- Ensure Git, Bash, `mise`, and normal Elixir dependencies are available.

## Scenario 1: Human source quick start

1. Open `README.md` without consulting another file.
2. Confirm its source sequence includes clone/location context, `elixir/`, `mise` setup, Mix setup, and build.
3. Confirm generic launch uses an explicit workflow path and names successful startup evidence.
4. Confirm GitHub orchestration routes to focused App/onboarding guidance.

**Expected outcome**: A reader copies the generic sequence in order with no undocumented directory transition and cannot confuse it with GitHub execution.

## Scenario 2: Agent command discovery

1. Open `elixir/AGENTS.md`.
2. Confirm it identifies setup, build, validation, and launch with directory assumptions.
3. Follow generic and GitHub links to the Elixir README and agent runbook or applicable focused guide.

**Expected outcome**: An agent finds canonical commands without guessing and is not directed to expose credentials or run orchestration from an issue workspace.

## Scenario 3: Cross-surface consistency

Compare `README.md`, `elixir/README.md`, `elixir/AGENTS.md`, `.symphony/README.md`, and
`elixir/docs/agent-installation.md`. Confirm source setup order, working directories, workflow
paths, mode labels, credentials, and workspace boundaries agree with the
[documentation contract](contracts/documentation-surfaces.md).

**Expected outcome**: No conflicting install, build, validation, or launch instruction remains.

## Automated and repository checks

Run focused link/path checks selected during implementation, then:

```bash
git diff --check
make -C elixir all
```

Review the final diff to ensure `SPEC.md`, runtime code, generated artifacts, credentials, and
unrelated files are unchanged.

**Expected outcome**: All focused checks and the repository quality gate pass, or any dependency
advisory/external omission is explicitly reported at handoff.
