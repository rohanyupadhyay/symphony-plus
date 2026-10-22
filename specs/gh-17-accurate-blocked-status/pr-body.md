#### Context

Blocked and quota-paused sessions could appear healthy or be counted more than once across status surfaces. Tracks #17.

#### TL;DR

*Classify each runtime issue once and show accurate blocked or quota-waiting status everywhere.*

#### Summary

- Add one shared, secret-safe runtime status projection with deterministic lifecycle precedence
- Use normalized lists and counts in terminal, JSON, and LiveView status surfaces
- Add overlap, reason-safety, presenter, terminal snapshot, and live-refresh regressions
- Document blocked and recoverable quota semantics in the product and operator guides

#### Alternatives

- Per-renderer fixes were rejected because they preserve duplicated policy and cross-surface drift.
- New persistence was rejected because the defect is in the read projection, not state ownership.

#### Test Plan

- [x] `make -C elixir all` (`TMPDIR=/tmp`; 415 tests, 0 failures, 6 skipped, 100% coverage)
- [x] Focused runtime, orchestrator, terminal snapshot, and extension tests (67 tests, 0 failures)

Dependency advisory output: the existing lockfile reports HIGH/MEDIUM/LOW advisories in Bandit,
Decimal, HPAX, LazyHTML, Mint, Phoenix, Phoenix LiveView, Plug, and Req. Dependency upgrades are
outside this feature's status-projection scope.
