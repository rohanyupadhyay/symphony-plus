# Data Model: Single Multi-Repository Service

## Project Registration

| Field | Type | Rules |
|---|---|---|
| `id` | string | Stable opaque ID derived from canonical workflow path; unique |
| `workflow_path` | string | Canonical absolute path; unique; no workflow content/credentials |

The registry envelope is `{version: 1, projects: [...]}`. Unknown versions, duplicate IDs, and
duplicate paths are rejected without overwriting durable data.

## Project Runtime

| Field | Type | Rules |
|---|---|---|
| `registration` | Project Registration | Required |
| `state` | `unavailable \| starting \| active \| stopping` | Exactly one |
| `workflow` | loaded workflow or null | Present only after validation |
| `workspace_root` | absolute path or null | Validated/collision-free before activation |
| `failure_reason` | string or null | Single-line, bounded, non-secret |
| `last_checked_at` | timestamp | Updated per validation attempt |
| `runtime_ref` | child reference or null | Present while starting/active/stopping |

```text
restored/added -> unavailable -> starting -> active
                     ^              |          |
                     |--------------|----------| failure/retry
active -> stopping -> removed (only with no retained issue work)
```

## Project Registry

One GenServer mirrors the last successfully persisted registration set and ephemeral runtime
statuses. Add succeeds only after validation and atomic persistence; activation failure retains an
unavailable registration. Remove first proves idle, then persists, then terminates the runtime,
without deleting repositories, workflows, workspaces, or history.

## Service Snapshot

`projects` contains all registrations; aggregate counts derive from project snapshots; every issue
row includes `project_id`; project failure summaries contain no workflow body, credential, or raw
exception payload.

## Invariants

- New paths must be readable regular files and pass existing workflow/schema validation.
- Restored registrations remain durable when later invalid.
- Canonical workflow paths and resolved workspace roots are pairwise unique.
- Duplicate add returns the existing record; absent remove does not mutate storage.
- Active, retrying, quota-waiting, or blocked issue state prevents removal.
