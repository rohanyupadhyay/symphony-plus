# Feature Specification: Document Dispatch Label Requirement

**Feature Branch**: `symphony/gh-5-dispatch-label-doc`

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "Add one sentence to the self-hosting operator guide explaining that dispatch requires the symphony label."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Recognize the Dispatch Prerequisite (Priority: P1)

As a self-hosting operator, I can learn from the operator guide that an issue must carry the
`symphony` label before Symphony can dispatch it, so I can prepare issues without mistaking an
unlabeled issue for eligible work.

**Why this priority**: This is the entire requested documentation outcome and prevents confusion at
the point where an operator decides whether an issue is ready for automated execution.

**Independent Test**: Review the self-hosting operator guide and confirm that one sentence states
both the required label name and its relationship to dispatch eligibility.

**Acceptance Scenarios**:

1. **Given** an operator reads the self-hosting operator guide, **When** they look for issue dispatch
   prerequisites, **Then** one sentence states that dispatch requires the `symphony` label.
2. **Given** an issue does not carry the `symphony` label, **When** the operator applies the documented
   rule, **Then** they understand that the issue is not eligible for dispatch.

### Edge Cases

- The sentence must not imply that merely creating the `symphony` label dispatches an issue; the
  label must be applied to that issue.
- The sentence must identify the label exactly as `symphony` so operators do not infer a variant.
- The change must not claim that the label is the only dispatch condition, because other configured
  eligibility rules continue to apply.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The self-hosting operator guide MUST include exactly one new sentence explaining that
  issue dispatch requires the `symphony` label.
- **FR-002**: The new sentence MUST present `symphony` as the exact label an issue must carry.
- **FR-003**: The new sentence MUST describe the label as a dispatch prerequisite without implying
  that it is sufficient on its own for dispatch.
- **FR-004**: The change MUST be limited to documentation and MUST NOT alter dispatch behavior,
  configuration, or the normative product contract.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The self-hosting operator guide gains exactly one sentence about the dispatch label
  requirement.
- **SC-002**: A reviewer can identify both the exact label name and its prerequisite relationship to
  dispatch from that sentence alone.
- **SC-003**: Review of the change finds zero modifications outside the documentation sentence and
  its Spec Kit workflow artifacts.
- **SC-004**: The documented rule remains consistent with the existing normative dispatch contract
  and introduces zero new behavioral requirements.

## Assumptions

- The self-hosting operator guide is `.symphony/README.md`, as linked from the repository root
  README.
- The existing configured dispatch label is the lowercase label `symphony`.
- Existing dispatch behavior already enforces configured required labels; this change only makes
  that prerequisite explicit for self-hosting operators.
- The specific placement and prose of the sentence may follow the guide's current structure, while
  preserving all requirements above.

## Out of Scope

- Changing label configuration, dispatch logic, issue state handling, or workflow control.
- Updating `SPEC.md`, because the normative label eligibility rule already exists there.
- Adding more than one sentence to the self-hosting operator guide.
- Planning, implementation, pull-request creation, or any phase beyond specification approval in
  this smoke-test run.
