# Quickstart: Validate Safe Automatic Updates

## Automated gate

```bash
cd elixir
mise trust
mise install
mise exec -- mix setup
mise exec -- mix test test/symphony_plus/source_update_test.exs test/symphony_plus/update_manager_test.exs test/symphony_plus/orchestrator_test.exs
cd ..
make -C elixir all
```

## Scenarios

1. **Disabled**: omit `updates`, observe past an interval, and assert zero fetches/mutations and `disabled` status.
2. **Drain and activate**: enable against a temporary clone/local bare remote, run admitted work plus a continuation, advance remote to a known SHA, and make unrelated work runnable. Assert exact candidate SHA, no new dispatch, uninterrupted admitted work, idle merge queue, and restart on that SHA.
3. **Unsafe checkout**: repeat with tracked/untracked changes, detached/divergent HEAD, wrong remote, moved branch, and held lock. Assert no reset/rebase/deletion/workspace mutation and a bounded recovery cue.
4. **Restart recovery**: seed issue workspaces, checkpoints, quota waits, and merge-queue admissions. Assert all reconcile after restart and updater never touches issue workspaces.
5. **Activation failure**: fail after old process exit and before new health. Assert the preserved prior executable starts, a blocked outcome is recorded, and no unbounded loop or destructive history rewrite occurs.

## Implementation evidence (2026-10-23)

- Configuration/source boundary: `mix test test/symphony_plus/source_update_test.exs test/symphony_plus/update_config_test.exs` — 5 tests, 0 failures.
- Manager scheduling: `mix test test/symphony_plus/update_manager_test.exs` — 2 tests, 0 failures.
- Adjacent lifecycle/status suite: orchestrator, merge queue, runtime status, dashboard snapshots,
  presenter, configuration, source, and manager — 44 tests, 0 failures after snapshot refresh.
- Full gate: first run reached coverage with one expected observability contract fixture mismatch and
  exposed the repository's pre-existing dependency advisories; the fixture was updated to include
  the new unified `update` status object. Final result is recorded after the convergence pass.
- Preparation/restart allowance: two configured check intervals plus measured `prepare_command`
  runtime and external supervisor restart time; the updater does not impose a hidden fixed timeout.
- Convergence cycle 1 appended T040–T043 for controlled old-process shutdown, live remote movement
  revalidation, direct activation-helper evidence, and stable activation logs. The follow-up
  implementation completed all four; the 36-test source/helper/manager/orchestrator/queue suite
  passes with zero failures.
- Convergence cycle 2 appended and completed T044 for cross-process preparation serialization and
  process-unique worktrees. Convergence cycle 3 found no remaining actionable gap across 17 FRs,
  6 buildable success criteria, 8 acceptance scenarios, 7 plan decisions, and 6 constitution
  principles.
