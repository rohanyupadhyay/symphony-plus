# Research: Safe Automatic Updates

## Dedicated lifecycle owner

**Decision**: One supervised `UpdateManager` owns scheduling, candidate state, locking, drain coordination, and status.

**Rationale**: Prevents overlapping checks/activation without enlarging the issue scheduler's ownership.

**Rejected**: Putting all state in `Orchestrator` couples repository mutation to scheduling; cron cannot observe continuations or queue activity.

## Orchestrator-owned drain gate

**Decision**: Add idempotent drain/cancel and atomic quiescence calls. Drain blocks fresh unrelated work while claimed work and automatic continuations finish.

**Rationale**: Only the orchestrator can close the observation/dispatch race.

**Rejected**: Reading public status races new dispatch; suppressing continuations contradicts the specification.

## Immutable detached preparation

**Decision**: Fetch the existing remote's advertised default branch, key candidates by full SHA, and validate in a detached temporary worktree outside issue workspaces.

**Rationale**: Branches move; detached preparation keeps the current service usable on validation failure.

**Rejected**: Direct `git pull` mutates before validation; release assets are out of scope.

## External fast-forward activation

**Decision**: Under the installation lock, an external helper waits for the BEAM to exit, verifies old/candidate SHAs, performs fast-forward-only activation, installs the prepared build, and restarts. Preserve the prior executable for recovery.

**Rationale**: The handoff must survive process exit and must avoid destructive rollback.

**Rejected**: In-process restart cannot finish after exit; `reset --hard` is forbidden; multi-release deployment is speculative.

## Authentication and configuration

**Decision**: Use the checkout's Git remote/credentials. Add a validated opt-in `updates` block to `Config.Schema`; invalid reload retains last known good, and disabling cancels pending drain.

**Rationale**: Preserves host credential boundaries, repository-owned policy, and current reload semantics.

**Rejected**: Raw GitHub App credentials violate the host boundary; REST discovery duplicates Git; environment-only policy bypasses `Config`.

## Unified status

**Decision**: One `UpdateManager.status/0` snapshot feeds terminal, JSON, LiveView, and logs. States: `disabled`, `current`, `checking`, `preparing`, `pending`, `draining`, `activating`, `blocked`, `failed`.

**Rationale**: Prevents surface drift and satisfies the required operator evidence.
