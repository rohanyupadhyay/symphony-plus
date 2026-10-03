# Data Model: Pull Request Tracking Reference

This feature adds no persisted Symphony entity or database state. It constrains existing GitHub and workflow concepts.

## Originating Issue

- **Repository**: the configured `owner/repository`; required and identical to the pull request repository.
- **Number**: positive GitHub issue number exposed as `issue.id` to the workflow template.
- **State**: remains open through PR creation, updates, closure without merge, and merge observation; closure is a separate authorized workflow action.

## Pull Request

- **Repository**: same configured repository as the originating issue.
- **Branch**: the issue's single durable feature branch.
- **Body**: conforms to the target repository's PR template and contains exactly one tracking reference.
- **Lifecycle**: created once, updated in place across revisions, and later open, closed-unmerged, or merged.

## Tracking Reference

- **Canonical form**: `Tracks #<issue-number>`.
- **Cardinality**: exactly one per pull-request body for the originating issue.
- **Semantics**: a non-closing GitHub autolink/cross-reference, not a Development closing relationship.
- **Validation rules**:
  - The issue number comes from the active workflow issue, not user-authored free text.
  - The reference uses same-repository shorthand only.
  - No `close`, `fix`, or `resolve` keyword variant prefixes the issue reference.
  - Updates preserve one canonical occurrence rather than appending another.

## Relationships and State Transitions

```text
Originating Issue (open) 1 ── tracked by ── 1 Pull Request
                                      │
                                      └── body contains 1 Tracking Reference

PR create/update/revision ──> issue stays open
PR close without merge    ──> issue stays open; workflow asks for next action
PR merge                  ──> issue stays open until explicit merged-PR handling closes it
```
