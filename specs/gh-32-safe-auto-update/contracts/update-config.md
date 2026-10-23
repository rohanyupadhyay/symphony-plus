# Contract: Automatic Update Configuration

Omission equals `enabled: false`.

```yaml
updates:
  enabled: false
  interval_ms: 900000
  installation_root: /absolute/path/to/symphony-plus
  remote: origin
  prepare_command: mise exec -- mix setup && make all && mise exec -- mix build
  launcher_command: ./scripts/run-github
```

- `enabled` is boolean, default false; `interval_ms` is positive.
- When enabled, root and commands are required.
- Root is absolute, identifies the expected repository, and is outside `workspace.root`.
- Remote is a simple existing name, default `origin`.
- Invalid settings reject the whole reload and preserve the prior workflow.
- Disabling cancels a non-activating candidate and releases drain.
- Literal credentials, tokens, and keys are not accepted.
- First release intentionally has no channel, tag, downgrade, release-asset, or executable replacement fields.
