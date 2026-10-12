# Quickstart: Validate Accurate Blocked Session Status

## Prerequisites

```bash
cd elixir
mise trust
mix setup
```

## Focused validation

```bash
mix test test/symphony_elixir/runtime_status_test.exs
mix test test/symphony_elixir/orchestrator_status_test.exs
mix test test/symphony_elixir/status_dashboard_snapshot_test.exs
mix test test/symphony_elixir/extensions_test.exs
```

Expected outcomes:

1. An ordinary operator-input pause appears once as blocked with a concise reason.
2. A renewable quota record appears once as quota-waiting with pool and next-time context.
3. An `operator_blocked` quota record appears once as blocked, retains safe quota context, and is absent from quota-waiting.
4. Deliberately overlapping running, retrying, quota, and blocked inputs resolve deterministically and counts equal list lengths.
5. Terminal, JSON, and LiveView output agree on primary terminology and diagnostic context.
6. Control characters and overlong reason text do not create unsafe or unbounded display output.

## Lifecycle validation

Exercise running-to-blocked and release, running-to-quota-wait and resume, quota-wait-to-operator-blocked, retry, cancellation, terminal state, eligibility loss, cleanup, durable restart reconstruction, LiveView PubSub refresh, and whole-snapshot timeout/unavailable behavior. The first completed snapshot after each transition must contain no stale or conflicting primary classification.

## Full gate

```bash
make -C elixir all
```

Review the final diff for secrets, raw provider payloads, unrelated dashboard redesign, generated artifacts, incomplete tasks, and documentation drift.
