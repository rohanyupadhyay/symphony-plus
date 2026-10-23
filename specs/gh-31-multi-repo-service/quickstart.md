# Quickstart Validation: Single Multi-Repository Service

Use Elixir 1.19/OTP 28 and two valid repository-owned workflows with distinct workspace roots.

1. Start from `elixir/` without a positional workflow and with an empty data root. Within 10 seconds,
   dashboard/API must show healthy zero-project state and an add action.
2. Add one workflow in LiveView and one via `bin/symphony-plus projects add`. CLI/dashboard/API must
   agree; both activate without restart; issue rows show project attribution.
3. Re-add a path through both interfaces: no duplicate. Break one workflow: only that project becomes
   unavailable. Repair it: automatic activation occurs without re-registration/restart.
4. Restart with the same data root: all registrations return. The JSON contains only version, IDs,
   and paths; no tracked file changes. Make storage unwritable: mutation fails with no partial state.
5. Remove a project with retained work: refusal explains recovery. Once idle, removal affects only
   registration/runtime. Removing the final project restores healthy empty state.
6. Run focused registry/runtime/CLI/LiveView tests, then `make all` from `elixir/`.
