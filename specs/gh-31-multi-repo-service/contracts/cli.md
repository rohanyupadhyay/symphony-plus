# CLI Contract: Project Management

## Launch

```text
symphony-plus [--logs-root PATH] [--data-root PATH] [--port PORT]
```

Startup permits zero registrations. A legacy positional workflow path is migrated through the same
registry before startup, never a separate singleton mode. Existing guardrails acknowledgement stays.

## Commands

```text
symphony-plus projects list [--data-root PATH] [--format table|json]
symphony-plus projects add WORKFLOW_PATH [--service-url URL]
symphony-plus projects remove PROJECT_ID [--service-url URL]
```

- `list` returns ID/path and, online, state/safe reason.
- `add` canonicalizes, validates, rejects workspace conflicts, persists atomically, and activates;
  duplicate add succeeds idempotently and identifies the existing project.
- `remove` refuses retained work and never deletes project files/workspaces.
- Mutations require the running local service; connection failure never writes directly.
- Exit `0` means success/idempotent success; `1` means rejected or failed.
