# Quickstart: Validate Quota-Aware Harness Resume

## Prerequisites

- Elixir 1.19 / OTP 28 through `mise`; dependencies installed with `cd elixir && mix setup`.
- Temporary `WORKFLOW.md` and workspace root.
- Deterministic fake tracker and Codex app-server fixtures; no live quota required.

## Contract checks

Use [the harness contract](contracts/harness-quota-resume.md), [JSON schema](contracts/quota-wait-state.schema.json), and [state model](data-model.md).

## Focused red/green scenarios

```bash
cd elixir
mix test test/symphony_elixir/app_server_test.exs \
  test/symphony_elixir/quota_wait_store_test.exs \
  test/symphony_elixir/orchestrator_status_test.exs \
  test/symphony_elixir/workspace_and_config_test.exs \
  test/symphony_elixir/status_dashboard_snapshot_test.exs
```

The suite must prove:

1. Pinned Codex quota signals classify correctly; lookalike transport/auth/permission/billing/free-text errors do not.
2. Entry persists atomically, releases the slot, preserves workspace, avoids retry increments, and suppresses same-pool dispatch.
3. Repeated polls and duplicate signals create no duplicate wait, timer, or run.
4. Restart reloads records, reconciles eligibility, and launches nothing before due time.
5. Due eligible work reserves once, calls `thread/resume`, and starts one continuation without `thread/start` fallback.
6. Second exhaustion returns to waiting; unavailable/mismatched threads block with workspace/checkpoint preserved.
7. Cancellation, terminal/label/dispatchability changes, workspace deletion, reload, malformed state, and persistence failure follow safe paths.
8. API/dashboard/logs distinguish waiting/retrying/blocked and omit secrets/raw payloads.

## Documentation and full validation

Update `SPEC.md`, root `README.md`, `elixir/README.md`, `elixir/docs/logging.md`, and the focused
quota-resume guide. New public functions need adjacent `@spec` declarations.

```bash
cd elixir
mix specs.check
cd ..
make -C elixir all
```

Finally review the diff for secrets, provider payloads, unrelated changes, generated artifacts,
unchecked tasks, and constitution or `SPEC.md` divergence.
