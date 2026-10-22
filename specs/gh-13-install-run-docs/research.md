# Research: Install and Run Documentation

## Decision 1: Canonical source-install owner

- **Decision**: Keep `elixir/README.md` as the canonical detailed source-install and generic-run reference; add a compact sequence to the root README and link agent summaries back to it.
- **Rationale**: The Elixir README already owns prerequisites, releases, configuration, and runtime detail. A root quick start improves discovery without creating a second full manual.
- **Alternatives considered**: Make the root README canonical (duplicates detail); only link from root (does not provide the requested copyable quick start).

## Decision 2: Supported source command sequence

- **Decision**: Use `git clone`, `cd symphony-plus/elixir`, `mise trust`, `mise install`, `mise exec -- mix setup`, `mise exec -- mix build`, and `mise exec -- ./bin/symphony-plus <workflow-path>`.
- **Rationale**: This matches current documentation, the checked-in toolchain, and Mix build flow. An explicit workflow argument avoids current-directory ambiguity.
- **Alternatives considered**: Raw `mix` outside `mise` (does not guarantee supported versions); only prebuilt releases (does not cover source installation); omit the workflow argument (weakens clarity).

## Decision 3: Separate generic and GitHub modes

- **Decision**: Present `bin/symphony-plus` as generic local/custom-workflow execution and route GitHub orchestration to `scripts/run-github`, the agent runbook, and self-hosting guide.
- **Rationale**: GitHub mode requires an operator-owned App profile, repository-owned workflow, dedicated workspace root, and host-side credential handling.
- **Alternatives considered**: Put GitHub startup in the basic quick start (implies missing setup); show both modes as equivalent (obscures safety boundaries).

## Decision 4: Documentation ownership

- **Decision**: Root README owns discovery; `elixir/README.md` owns generic detail; `elixir/AGENTS.md` owns agent development commands; the agent runbook owns target-repository onboarding; `.symphony-plus/README.md` owns this repository's operator procedure.
- **Rationale**: These distinct audiences already exist. Explicit ownership reduces drift.
- **Alternatives considered**: Duplicate everything everywhere (drift risk); create another guide (adds an unnecessary owner and navigation hop).

## Decision 5: Validation

- **Decision**: Validate Markdown links and named executable paths, compare repeated commands, run whitespace checks, and retain the full Elixir quality gate.
- **Rationale**: Primary risks are broken references, command drift, and unsafe instructions; the constitution also requires `make -C elixir all` at handoff.
- **Alternatives considered**: Manual review only (not reproducible); a real configured orchestration run (requires credentials and external state beyond scope).
