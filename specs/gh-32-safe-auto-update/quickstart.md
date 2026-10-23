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
