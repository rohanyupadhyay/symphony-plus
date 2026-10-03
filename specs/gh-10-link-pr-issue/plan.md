# Implementation Plan: Link Pull Requests to Source Issues

**Branch**: `symphony/gh-10-link-pr-issue` | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/gh-10-link-pr-issue/spec.md`

## Summary

Make the reusable GitHub Spec Kit workflow require exactly one same-repository, non-closing
`Tracks #{{ issue.id }}` reference in every created or updated pull-request body. Keep the agent
workflow as the single owner of pull-request composition, preserve the repository PR template,
document why closing keywords are forbidden, and add a focused regression assertion for the
shipped workflow template. No Elixir runtime API or persisted state is needed.

## Technical Context

**Language/Version**: Elixir 1.19 on OTP 28 for the focused regression test; Liquid/Markdown/YAML for workflow policy

**Primary Dependencies**: Existing `SymphonyElixir.Workflow` loader, Solid/Liquid prompt rendering, ExUnit, GitHub issue and pull-request presentation

**Storage**: N/A; the relationship is represented once in the GitHub pull-request description

**Testing**: ExUnit targeted template-contract test, `mix pr_body.check` for a representative body, and `make -C elixir all`

**Target Platform**: GitHub repositories using Symphony Plus's reusable Spec Kit workflow

**Project Type**: Long-running Elixir service with repository-owned Markdown workflow prompts

**Performance Goals**: No additional API calls or polling work; one static reference is added during the existing PR create/update operation

**Constraints**: Preserve the PR template; never use GitHub closing keywords; remain idempotent across revisions; same-repository issues only; human merge remains mandatory

**Scale/Scope**: One pull request per issue branch and one tracking reference per pull-request body; reusable template, focused documentation, and regression coverage only

## Constitution Check

*GATE: Passed before Phase 0 research and passed again after Phase 1 design.*

- **I. Specification and Contract Alignment — PASS**: The design follows `SPEC.md`'s boundary that tracker writes belong to agent tooling and workflow policy. The reusable workflow and focused operator documentation are updated together.
- **II. Workspace and Credential Safety — PASS**: No credential, workspace, push, or host-tool boundary changes are introduced. The existing `github_api`/`github_git_push` path remains authoritative.
- **III. Lifecycle and Recovery Correctness — PASS**: Creation, resume/update, revision, merged, and closed-without-merge paths are explicitly covered. A stable body line makes retries idempotent and leaves issue closure to the existing merged-PR workflow step.
- **IV. Simplicity and Clear Ownership — PASS**: The workflow prompt remains the sole owner of PR composition. No new runtime abstraction, API, configuration, or duplicated relationship state is added.
- **V. Evidence-Driven Validation — PASS**: Implementation will begin with a focused failing assertion against the reusable template, then update the prompt and run targeted plus full gates.
- **VI. Operational Observability — PASS**: No new runtime event is introduced. Documentation will make the relationship and separate closure responsibility visible to operators.

No constitution exceptions or complexity justifications are required.

## Project Structure

### Documentation (this feature)

```text
specs/gh-10-link-pr-issue/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── pr-tracking-reference.md
└── tasks.md
```

### Source Code (repository root)

```text
elixir/
├── examples/
│   └── github-speckit-WORKFLOW.md
├── docs/
│   └── github-workflow-control.md
└── test/
    └── symphony_elixir/
        └── github_launcher_test.exs
```

**Structure Decision**: Extend the existing reusable workflow prompt and its focused workflow-control guide, with a regression assertion in the existing template test module. The self-hosting `.symphony/WORKFLOW.md` already demonstrates the intended wording and does not need a second implementation path.

## Complexity Tracking

No constitution violations require justification.
