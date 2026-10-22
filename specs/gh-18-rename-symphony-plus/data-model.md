# Data Model: Product Identity Rename

This feature introduces no new business entity or database. It migrates repository-controlled identity values and the filesystem/GitHub records that carry them.

## Product Identity

| Field | Required value | Validation |
|---|---|---|
| Display name | `Symphony Plus` | Exact case in maintained prose and UI |
| Machine slug | `symphony-plus` | Lowercase kebab case |
| Elixir module root | `SymphonyPlus` | Exact module prefix |
| Elixir web module root | `SymphonyPlusWeb` | Exact module prefix |
| OTP application/release | `:symphony_plus` | Exact atom |
| Environment prefix | `SYMPHONY_PLUS_` | Exact uppercase prefix for repository-controlled variables |

All repository-controlled product identities have exactly one canonical value. No legacy aliases are valid after the migration.

## Renamed Interface Record

Represents each controlled surface in the audit.

- `surface`: executable, command, label, path, branch, artifact, application, module, environment variable, log/UI text, fixture, or documentation.
- `location`: repository path or live GitHub label.
- `old_value`: legacy product-bearing value.
- `new_value`: canonical interface-specific value.
- `owner`: code, workflow policy, release automation, documentation, or GitHub metadata.
- `lifecycle_paths`: applicable startup, reload, restart, dispatch, retry, reconciliation, cancellation, cleanup, or release flows.
- `validation`: focused assertion or audit evidence proving the new contract.

Validation rules:

1. Every repository-controlled record has a non-empty `new_value` matching the identity matrix.
2. No record maps to both a new value and a compatibility alias.
3. Stateful records identify every applicable lifecycle path.
4. A rename of a file/directory includes updates to all maintained inbound references.

## Persisted Filesystem Identity

Controlled persisted names include quota-wait directories, GitHub App profile directories, logs, default workspace roots, release filenames, and service fixtures.

State transition:

```text
legacy path (unsupported after change)
    -> operator starts renamed version
canonical Symphony Plus path created/read
    -> normal lifecycle behavior continues
```

The application does not automatically copy, move, or fall back to legacy paths. Workspace boundary validation, atomic writes, cleanup scoping, and secret handling remain unchanged.

## Workflow-Control Identity

- Eligibility label: `symphony-plus`
- Slash-command prefix: `/symphony-plus`
- Managed branch prefix: `symphony-plus/`
- Repository workflow directory: `.symphony-plus/`
- Durable checkpoint schema: unchanged; only product-bearing prose and configured values change.

The label's GitHub identity is renamed in place so existing issue associations remain. During the active issue workflow, the metadata transition occurs only after repository contracts are ready.

## Legacy Occurrence Classification

Each retained whole-word legacy occurrence must have one classification:

- `upstream`: accurately names or links to OpenAI Symphony.
- `historical`: necessary provenance that clearly distinguishes the upstream predecessor.
- `immutable_external`: identifier outside repository control that cannot safely change.

Unclassified occurrences are invalid. `compatibility` is not an allowed classification for this feature.
