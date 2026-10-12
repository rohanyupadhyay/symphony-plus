# Symphony Plus Naming Contract

## Canonical mappings

| Surface | Contract |
|---|---|
| Product prose and UI | `Symphony Plus` |
| Executable and startup command | `symphony-plus` and `./bin/symphony-plus` |
| Repository workflow directory | `.symphony-plus/` |
| GitHub eligibility/PR label | `symphony-plus` |
| Workflow-control prefix | `/symphony-plus` |
| Managed branch prefix | `symphony-plus/` |
| Release/artifact prefix | `symphony-plus-` |
| Elixir module roots | `SymphonyPlus`, `SymphonyPlusWeb` |
| OTP application and release | `:symphony_plus` |
| Repository-controlled environment variables | `SYMPHONY_PLUS_*` |
| Repository-controlled profile/state/log slugs | `symphony-plus` |

## CLI contract

```text
./bin/symphony-plus [WORKFLOW_PATH] [--logs-root PATH] [--port PORT]
./bin/symphony-plus github-app setup OWNER/REPOSITORY [--profile NAME]
./bin/symphony-plus github-app verify OWNER/REPOSITORY [--profile NAME]
```

The option semantics are unchanged. `symphony` is not a supported executable alias.

## Workflow-control grammar

```text
/symphony-plus approve spec
/symphony-plus approve plan
/symphony-plus approve implementation
/symphony-plus answer <answer>
/symphony-plus revise <instructions>
/symphony-plus retry
/symphony-plus status
/symphony-plus cancel
```

Authorization, normalization, checkpoint state, and merge-queue behavior remain unchanged. `/symphony ...` is not recognized as a supported alias.

## Repository path contract

Repository-local workflow assets live under:

```text
.symphony-plus/WORKFLOW.md
.symphony-plus/README.md
```

Runtime persisted product paths use `symphony-plus` consistently. The implementation must continue validating that every workspace/state mutation remains under its configured root.

## Release contract

- Mix escript output: `elixir/bin/symphony-plus`
- Burrito release identity: `:symphony_plus`
- Stable artifact pattern: `symphony-plus-v<VERSION>-<TARGET>` plus checksum
- Nightly artifact pattern: the same prefix with the existing nightly version semantics
- Release titles and notes name Symphony Plus.

## Compatibility and exceptions

There are no repository-controlled aliases for legacy names. Accurate `openai/symphony` links and prose identifying the upstream OpenAI Symphony project may remain when their context makes that ownership explicit. Immutable external identifiers may remain only with documented justification.
