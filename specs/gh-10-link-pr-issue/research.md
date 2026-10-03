# Research: Link Pull Requests to Source Issues

## Decision 1: Use a plain non-closing issue reference in the PR body

**Decision**: Require the exact line `Tracks #{{ issue.id }}` once in every Symphony-created or updated pull-request description.

**Rationale**: GitHub autolinks same-repository `#<number>` references and creates a reciprocal cross-reference without a closing keyword. This gives reviewers and issue participants bidirectional navigation while leaving issue closure under the durable workflow's explicit merged-PR handling.

**Alternatives considered**:

- GitHub closing keywords (`close`, `fix`, or `resolve` variants): rejected because GitHub documents them as automatic issue-closure triggers when merged into the default branch.
- A manually linked Development relationship: rejected because GitHub's linked-issue lifecycle can close the issue on merge and would add a second mutable relationship operation.
- A separate issue comment containing the PR URL: rejected because it duplicates the native cross-reference already created by the PR-body mention and creates retry/idempotency work.

## Decision 2: Keep relationship creation in workflow policy

**Decision**: Put the invariant in `elixir/examples/github-speckit-WORKFLOW.md`, where the agent already owns PR body creation and updates through `github_api`.

**Rationale**: `SPEC.md` explicitly places ticket writes and PR links behind provider-native agent tools rather than orchestration business logic. The self-hosting workflow already proves the prompt-level pattern. Extending the reusable template fixes new installations without adding a runtime API or provider-specific state.

**Alternatives considered**:

- Add a dedicated Elixir endpoint/tool for linked issues: rejected as unnecessary duplicated policy and because a formal linked-issue relationship has the unwanted closure semantics.
- Change `github_api` to rewrite PR bodies: rejected because a generic REST proxy must not own repository-specific PR templates or issue policy.
- Modify only this repository's `.symphony/WORKFLOW.md`: rejected because it is already correct and would not repair the shipped reusable template.

## Decision 3: Preserve one reference during updates

**Decision**: The prompt contract requires the reference on both create and update paths, exactly once, within a body that still follows `.github/pull_request_template.md`.

**Rationale**: Revisions update the same pull request. Treating the full desired body as the invariant is naturally idempotent: an agent validates and updates one body rather than appending comments or relationship records on each resume.

**Alternatives considered**:

- Append `Tracks` during every revision: rejected because retries could duplicate the line.
- Add a new fixed heading to the repository template: rejected because target repositories have their own templates and the reference can coexist with them without changing template structure.

## Decision 4: Validate the shipped policy contract directly

**Decision**: Extend the existing reusable-template test in `elixir/test/symphony_elixir/github_launcher_test.exs` to assert the rendered policy contains the exact `Tracks #{{ issue.id }}` rule, forbids auto-closing keywords, and assigns issue closure to merged-PR handling.

**Rationale**: The defect is an omission in distributed prompt policy. A focused static contract test fails reproducibly before the prompt change and prevents future removal. Existing PR-body lint and the full Elixir gate provide complementary structure and repository-wide validation.

**Alternatives considered**:

- Live GitHub-only validation: rejected as the primary regression because it is credentialed, slow, and unsuitable for the mandatory local gate.
- Unit-test GitHub rendering behavior itself: rejected because GitHub owns that behavior; Symphony needs to test its emitted policy and representative body.

## Sources

- GitHub Docs, “Linking a pull request to an issue”: documents closing keywords, manual links, same-repository constraints, and automatic closure behavior.
- GitHub Docs, “Autolinked references and URLs”: documents issue/PR references and reciprocal links.
- Repository `SPEC.md`: assigns tracker writes and PR links to coding-agent provider tools.
- `.specify/memory/constitution.md`: requires lifecycle correctness, smallest coherent ownership, focused failing tests, full validation, and documentation.
