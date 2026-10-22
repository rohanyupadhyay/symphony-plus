# Research: Symphony Plus Repository-Wide Rename

## Decision 1: Use one canonical identity per interface

- **Decision**: Use `Symphony Plus` in prose/UI, `symphony-plus` for commands, paths, labels, branches, artifacts, profile folders, and releases, `SymphonyPlus`/`SymphonyPlusWeb` for Elixir modules, `:symphony_plus` for the OTP application/release atom, and `SYMPHONY_PLUS_*` for repository-controlled environment variables.
- **Rationale**: These forms follow the conventions of each interface while making the product identity unmistakable. A single matrix prevents drift during a broad migration.
- **Alternatives considered**: Keep `SymphonyElixir` internally (rejected because the issue includes internal names); use hyphens in Elixir identities (not valid for module names and awkward for atoms); retain `SYMPHONY_*` variables (rejected because aliases are explicitly out of scope).

## Decision 2: Make the rename intentionally breaking

- **Decision**: Do not preserve legacy executable, slash-command, label, directory, branch-prefix, environment-variable, application, or persisted-path aliases.
- **Rationale**: The approved spec explicitly requires removal rather than compatibility. Aliases would double the contract surface, prolong ambiguity, and violate the simplest coherent design.
- **Alternatives considered**: One-release deprecation aliases or dual-directory discovery (rejected as contrary to FR-012 and the approved assumption).

## Decision 3: Rename Elixir namespaces atomically

- **Decision**: Migrate `SymphonyElixir` to `SymphonyPlus`, `SymphonyElixirWeb` to `SymphonyPlusWeb`, `:symphony_elixir` to `:symphony_plus`, and corresponding source/test directories and configuration references in one coherent change.
- **Rationale**: Leaving old language-level identities would cause future code and diagnostics to reproduce stale branding. An atomic migration lets compile failures expose incomplete references.
- **Alternatives considered**: Rename only public strings and binaries (rejected because it does not satisfy the maintained-code audit); add forwarding modules (rejected as unsupported aliases and unnecessary abstraction).

## Decision 4: Treat persisted filesystem names as contracts, not data migrations

- **Decision**: New runs use renamed quota, profile, log, workspace-default, and related paths. No automatic migration or fallback reads from legacy repository-controlled paths are added.
- **Rationale**: The change is explicitly breaking and the current stores are reconstructible or operator-managed. Silent fallback would create compatibility behavior and ambiguous ownership.
- **Alternatives considered**: Copy/move legacy state automatically or read both locations (rejected due to filesystem safety risk and alias policy). Documentation will call out the new locations.

## Decision 5: Use classified auditing for retained legacy names

- **Decision**: Search whole-word, case-sensitive `Symphony` and `symphony` forms across maintained files and paths. Every remainder must be identified as an accurate upstream OpenAI Symphony reference or immutable external identifier; generated/dependency/VCS content is excluded.
- **Rationale**: Blind replacement would corrupt valid `openai/symphony` URLs, while an unclassified allowlist can hide regressions. Contextual classification provides deterministic evidence.
- **Alternatives considered**: Global textual replacement (unsafe); accept all URL occurrences (too broad); omit path-name scanning (would miss `.symphony/` and fixtures).

## Decision 6: Sequence the live GitHub label rename last

- **Decision**: Prepare code, workflow prompts, docs, and tests first; rename the repository label from `symphony` to `symphony-plus` only at a workflow-safe handoff through GitHub's API, preserving its issue associations.
- **Rationale**: The current label is the durable dispatcher trigger. Renaming it too early could strand the active issue; GitHub's label rename operation preserves associations when performed against the existing label.
- **Alternatives considered**: Create a second label and migrate issues (unnecessary dual state); rename immediately (risks interrupting the active workflow).

## Decision 7: Preserve behavior through focused lifecycle regression coverage

- **Decision**: Exercise startup/reload/restart, dispatch eligibility, durable checkpoint parsing, automatic-review/merge-queue handoff, quota resume, cancellation/cleanup, and release launch wherever renamed identifiers are involved.
- **Rationale**: The constitution requires adjacent lifecycle evidence for stateful changes. Naming changes touch persisted paths and workflow dispatch, so compilation and prose scans alone are insufficient.
- **Alternatives considered**: Rely exclusively on repository-wide replacement plus the existing full suite (rejected because it would not isolate failures at renamed boundaries).
