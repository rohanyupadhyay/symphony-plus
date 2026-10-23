# Data Model: Safe Automatic Updates

No database is added. `UpdateManager` owns runtime state; the repository, prepared worktree, lock, logs, and existing workflow stores survive restart.

## Update Policy

| Field | Type | Rules |
|---|---|---|
| `enabled` | boolean | Default false; disabled makes no request or mutation. |
| `interval_ms` | positive integer | Reschedules without overlapping a check. |
| `installation_root` | absolute path | Validated checkout, outside issue workspace root. |
| `remote` | string | Existing remote; default `origin`. |
| `prepare_command` | string | Runs only in detached candidate worktree. |
| `launcher_command` | string | External restart boundary without embedded credentials. |
| `lock_path` | derived path | Canonical installation-scoped lock. |

## Update Candidate

| Field | Type | Rules |
|---|---|---|
| `revision` | 40-character SHA | Immutable identity. |
| `default_branch` | string | Remote branch at detection. |
| `detected_at` | UTC timestamp | First observation. |
| `prepared_path` | path/nil | Detached worktree outside issue workspaces. |
| `preparation_state` | enum | `unprepared`, `preparing`, `ready`, `failed`. |
| `attempted` | boolean | Prevents repeated activation. |

## Update Admission

| Field | Type | Rules |
|---|---|---|
| `candidate_revision` | SHA | Must be ready. |
| `prior_revision` | SHA | Running revision at admission. |
| `drain_token` | reference | Current orchestrator drain generation. |
| `admitted_at` | timestamp | After atomic quiescence and idle queue replies. |
| `activation_state` | enum | `waiting`, `admitted`, `handoff_started`, `restarted`, `blocked`. |

## Update Status

| Field | Type | Rules |
|---|---|---|
| `state` | enum | `disabled`, `current`, `checking`, `preparing`, `pending`, `draining`, `activating`, `blocked`, `failed`. |
| `running_revision` | SHA/nil | Validated installation HEAD. |
| `candidate_revision` | SHA/nil | Current candidate. |
| `last_checked_at` | timestamp/nil | Last completed attempt. |
| `last_outcome` | bounded string | Stable identifier, never raw payload. |
| `reason` | bounded string/nil | Single-line recovery cue. |

## Transitions and invariants

```text
disabled -> checking -> current
                    -> preparing -> pending -> draining -> activating -> restarted
                           |           |          |             |
                           +--------> failed <----+----------> blocked
```

- One generation is active; a moved branch creates a new candidate.
- Pending owns one drain token; disabling or abandonment cancels it.
- Quiescence means no admitted running, retry, quota, workflow continuation, review, or queued/active merge work.
- Admission is rechecked immediately before spawning activation.
- Startup treats checkout HEAD as authoritative, safely clears owned temporary worktrees, reports stale locks, and lets existing stores reconstruct issue lifecycle.
