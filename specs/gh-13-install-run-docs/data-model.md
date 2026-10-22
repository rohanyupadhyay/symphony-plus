# Data Model: Install and Run Documentation

This feature introduces no persisted runtime entities. Its design model captures documentation
objects whose relationships must remain consistent.

## Documentation Surface

| Field | Meaning | Constraint |
|---|---|---|
| Path | Repository-relative Markdown path | Must resolve in the repository |
| Audience | Human evaluator, developer/agent, operator, or onboarding agent | One primary audience per surface |
| Authority | Discovery, canonical generic procedure, or canonical GitHub procedure | At most one canonical owner per procedure |
| Command references | Install, build, validate, or launch commands | Must agree with the owning guide |
| Safety references | Credential, source-checkout, workspace, and mode boundaries | Must not contradict `SPEC.md` or the constitution |

## Command Sequence

| Field | Meaning | Constraint |
|---|---|---|
| Prerequisites | Required host tools and access | Stated before execution |
| Start directory | Directory before the first command | Explicit or established by `cd` |
| Ordered steps | Toolchain, dependency, build, and launch commands | Copyable in order |
| Workflow path | Explicit workflow file passed to the launcher | Identifies generic versus repository-owned usage |
| Execution mode | Generic local or App-authenticated GitHub | Unambiguous |
| Expected outcome | Observable successful startup result | Must not invent behavior |

## Relationships

- `README.md` summarizes the generic sequence owned by `elixir/README.md`.
- `elixir/AGENTS.md` links to both generic and GitHub onboarding owners.
- `elixir/docs/agent-installation.md` owns end-to-end agent-operated GitHub onboarding.
- `.symphony-plus/README.md` specializes GitHub setup for this repository.
- All surfaces inherit safety constraints from `SPEC.md` and the constitution.

## State Transitions

No application state transition is introduced. Documentation moves only from implicit or
inconsistent instructions to audited, explicit, cross-linked instructions.
