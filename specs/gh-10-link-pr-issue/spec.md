# Feature Specification: Link Pull Requests to Source Issues

**Feature Branch**: `symphony/gh-10-link-pr-issue`

**Created**: 2026-10-01

**Status**: Draft

**Input**: User description: "When Symphony Plus creates a GitHub pull request from an issue, associate the pull request and issue using GitHub's supported relationship without causing either item to close automatically."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the source issue from the pull request (Priority: P1)

As a reviewer, I can identify the GitHub issue that a Symphony-created pull request tracks so I can understand the reason for the change without searching for it manually.

**Why this priority**: The pull request is the primary review surface, and reviewers need immediate access to its originating requirements and discussion.

**Independent Test**: Create a pull request through the Symphony issue workflow and inspect its GitHub relationships and description; the originating issue is visibly identified without any automatic closure behavior.

**Acceptance Scenarios**:

1. **Given** an open GitHub issue being advanced by Symphony, **When** Symphony creates a pull request for that issue, **Then** the pull request identifies that issue as the work it tracks.
2. **Given** a Symphony-created pull request that tracks an open issue, **When** the pull request is merged or closed, **Then** GitHub does not close the issue solely because of the tracking relationship.

---

### User Story 2 - See the pull request from the issue (Priority: P2)

As an issue participant, I can discover the Symphony-created pull request from the issue so I can follow implementation and review progress from the original work item.

**Why this priority**: Bidirectional discoverability keeps the issue useful as the durable workflow surface while review occurs on the pull request.

**Independent Test**: Create a pull request through the Symphony issue workflow and inspect the source issue; the pull request is discoverable through GitHub's native cross-reference or relationship UI.

**Acceptance Scenarios**:

1. **Given** an open GitHub issue, **When** Symphony creates a pull request that tracks it, **Then** the issue shows a native reference to the pull request.
2. **Given** repeated workflow activity for the same pull request, **When** Symphony updates or revises that pull request, **Then** it does not create redundant issue-to-pull-request links.

### Edge Cases

- The pull request description already contains a reference to the issue when Symphony resumes or updates it.
- The issue and pull request remain open across multiple workflow resumptions and revision cycles.
- The pull request is closed without merge; the issue remains open and available for the workflow's explicit next-step decision.
- The pull request is merged; the issue closes only through the workflow's separately authorized merged-PR handling, not through the relationship itself.
- The issue number must be rendered for the repository in which Symphony is operating, without accidentally referring to another repository.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every pull request created by Symphony from a GitHub issue MUST identify the originating issue through a GitHub-supported tracking reference.
- **FR-002**: The tracking reference MUST make the pull request discoverable from the originating issue through GitHub's native relationship or cross-reference presentation.
- **FR-003**: The tracking reference MUST NOT use wording or behavior that automatically closes the originating issue when the pull request is merged or closed.
- **FR-004**: Updating or revising an existing pull request MUST preserve one clear tracking relationship to the originating issue without adding redundant references.
- **FR-005**: The originating issue MUST remain open until the workflow explicitly closes it after observing a merged pull request or an authorized human closes it.
- **FR-006**: Pull request descriptions MUST continue to satisfy the repository's required pull request template while including the tracking reference.
- **FR-007**: The workflow documentation and product contract MUST describe the non-closing tracking relationship and the separate issue-closure responsibility.

### Key Entities

- **Originating Issue**: The GitHub issue that authorized the Symphony workflow; identified by repository and issue number and governed by the durable checkpoint state.
- **Pull Request**: The single review request created or updated for the issue branch; includes a non-closing reference to the originating issue.
- **Tracking Relationship**: GitHub's native cross-reference between the pull request and issue, distinct from an auto-closing relationship.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of Symphony-created pull requests, a reviewer can reach the originating issue directly from the pull request.
- **SC-002**: In 100% of source issues with a Symphony-created pull request, an issue participant can discover that pull request through GitHub's native presentation.
- **SC-003**: Merging or closing a tracked pull request causes zero automatic issue closures attributable to the tracking reference.
- **SC-004**: Repeated pull request updates produce no duplicate tracking references in the pull request description.
- **SC-005**: All affected automated validation scenarios pass, including initial creation, revision, merge, and close-without-merge paths.

## Assumptions

- GitHub's non-closing `Tracks #<issue>` reference is the repository's selected official relationship form.
- Symphony creates or updates one pull request per issue branch during this workflow.
- Existing explicit merged-PR handling remains responsible for closing the issue after merge.
- The relationship is recorded in the pull request description so it remains compatible with the required repository template.
- Cross-repository pull requests are outside this feature's scope; the originating issue and pull request belong to the configured repository.
