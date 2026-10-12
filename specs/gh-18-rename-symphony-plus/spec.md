# Feature Specification: Rename Symphony to Symphony Plus

**Feature Branch**: `symphony/gh-18-rename-symphony-plus`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "Replace the old product name Symphony with Symphony Plus and the machine-facing name symphony with symphony-plus everywhere, including the GitHub label, workflow directory, startup and other commands, README, and all other repository text."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Operate the Renamed Product (Priority: P1)

An operator installs, starts, configures, and controls the product using the Symphony Plus name and `symphony-plus` command vocabulary throughout the supported workflow.

**Why this priority**: Operators cannot adopt the new identity reliably while executable names, paths, labels, or control commands still require the old identity.

**Independent Test**: Starting from the documented setup instructions, an operator can build the executable, start the service with a repository workflow, and use every documented control command using only Symphony Plus naming.

**Acceptance Scenarios**:

1. **Given** a fresh checkout, **When** an operator follows the build and startup documentation, **Then** the produced executable and every startup example use `symphony-plus`.
2. **Given** a repository managed by the GitHub workflow, **When** an authorized user labels and controls an issue, **Then** the workflow recognizes the `symphony-plus` label and `/symphony-plus` commands.
3. **Given** a repository-local workflow contract, **When** the operator supplies its path, **Then** documentation and examples place it under `.symphony-plus/`.

---

### User Story 2 - Read Consistent Product Documentation (Priority: P2)

A reader encounters Symphony Plus as the product name in normative specifications, guides, user-facing messages, dashboards, examples, and repository metadata without unexplained legacy branding.

**Why this priority**: Mixed branding creates ambiguity about whether instructions and contracts apply to the fork or its upstream predecessor.

**Independent Test**: A repository-wide review of maintained product-facing content finds Symphony Plus naming wherever the repository refers to this product, while explicit historical or upstream references remain clearly identified as such.

**Acceptance Scenarios**:

1. **Given** any maintained repository document or user-visible product message, **When** it identifies this product, **Then** it says `Symphony Plus` rather than `Symphony`.
2. **Given** a deliberate reference to the upstream OpenAI project or an external immutable identifier, **When** it is retained, **Then** the surrounding text identifies it as upstream, historical, or externally controlled.
3. **Given** generated release artifacts and release metadata, **When** their names and titles are inspected, **Then** they consistently use `symphony-plus` or Symphony Plus as appropriate.

---

### User Story 3 - Maintain a Coherent Renamed Codebase (Priority: P3)

A maintainer can search, test, package, and extend the repository without encountering stale internal product identifiers that perpetuate the old name.

**Why this priority**: Internal names, fixtures, configuration keys, and paths otherwise cause new work to reproduce the legacy vocabulary and may break renamed commands.

**Independent Test**: Automated tests and a classified repository-wide legacy-name scan show that maintained internal identifiers, fixtures, defaults, and package outputs use the new machine-facing name, with every retained occurrence documented as an intentional compatibility or upstream reference.

**Acceptance Scenarios**:

1. **Given** the complete maintained source and test tree, **When** legacy product-name occurrences are classified, **Then** every occurrence is either renamed or explicitly justified as an external/upstream reference.
2. **Given** the renamed commands, paths, labels, and artifacts, **When** the full quality gate runs, **Then** tests assert the new vocabulary and pass.
3. **Given** an operator uses a removed legacy command, label, executable, or workflow directory, **When** the system evaluates it, **Then** it is not treated as a supported alias.

### Edge Cases

- References that intentionally identify the upstream `openai/symphony` repository must not be rewritten into a nonexistent upstream URL; their context must distinguish the upstream project from Symphony Plus.
- Immutable third-party identifiers, already-published references, protocol fields, or fixture data that cannot be renamed safely must remain only when classified and justified.
- Case-sensitive forms must map consistently: product prose uses `Symphony Plus`, while commands, labels, paths, artifact names, and other machine-facing slugs use `symphony-plus`.
- Composite names such as workspace roots, log paths, release filenames, application identifiers, and environment-variable documentation must not retain an ambiguous old product slug when controlled by this repository.
- The rename must not weaken workspace isolation, credential handling, workflow checkpoint durability, or merge-queue safety.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All maintained prose that names this product MUST use `Symphony Plus`, except explicit references to the upstream OpenAI Symphony project or another externally controlled proper name.
- **FR-002**: All repository-controlled user-facing commands and subcommand examples MUST use `symphony-plus` as the executable or command prefix.
- **FR-003**: The packaged executable, release target, release artifacts, release titles, and installation examples MUST use the `symphony-plus` machine-facing name.
- **FR-004**: The repository-local workflow directory convention MUST be `.symphony-plus/`, including workflow-file paths, operator guides, examples, and installation instructions.
- **FR-005**: GitHub workflow eligibility and pull-request metadata MUST use the `symphony-plus` label, and the repository label itself MUST be renamed from `symphony` to `symphony-plus` without losing issue association.
- **FR-006**: GitHub workflow-control commands, rendered guidance, parsing, examples, and tests MUST use the `/symphony-plus` prefix.
- **FR-007**: Repository-controlled branch naming examples and defaults MUST use the `symphony-plus/` prefix.
- **FR-008**: Repository-controlled internal identifiers, configuration defaults, filesystem names, log names, process/application metadata, test fixtures, and UI titles that encode the product identity MUST use a coherent Symphony Plus form appropriate to their interface.
- **FR-009**: Normative and operator documentation, including `SPEC.md`, the root README, Elixir README, focused guides, workflow examples, and templates, MUST describe the renamed interfaces consistently.
- **FR-010**: Tests MUST cover the renamed executable, workflow directory, label, workflow-control prefix, release naming, and representative user-visible product text.
- **FR-011**: A repository-wide legacy-name audit MUST classify every remaining whole-word `Symphony` or `symphony` occurrence and permit only intentional upstream, historical, immutable external, or compatibility references with clear justification.
- **FR-012**: Legacy repository-controlled names MUST NOT remain as supported aliases unless a later explicitly approved requirement introduces a compatibility policy.
- **FR-013**: The rename MUST preserve all existing orchestration, workspace-safety, credential-safety, lifecycle, recovery, review, and merge-queue behavior apart from the requested naming changes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of documented build, startup, installation, GitHub-control, and release examples use Symphony Plus naming and can be followed without substituting a legacy product name.
- **SC-002**: 100% of repository-controlled executable, workflow-directory, issue-label, command-prefix, branch-prefix, and release-artifact interfaces use the specified `symphony-plus` form.
- **SC-003**: A repository-wide case-sensitive legacy-name scan has zero unexplained occurrences; every retained occurrence is documented as upstream, historical, immutable external, or intentionally compatible.
- **SC-004**: All targeted rename tests and the repository full quality gate pass with no regressions in existing behavior.
- **SC-005**: An operator can complete the documented build-to-first-managed-issue path using only Symphony Plus naming at every repository-controlled step.

## Assumptions

- This is an intentional breaking rename: repository-controlled legacy executable names, labels, workflow directories, branch prefixes, and slash-command prefixes are removed rather than supported as aliases.
- References to `openai/symphony` remain unchanged when they identify the real upstream repository, but surrounding prose distinguishes upstream Symphony from this Symphony Plus fork.
- Language-level namespaces may be renamed when they are repository-controlled product identifiers; the implementation plan will inventory their migration impact before editing.
- Existing behavior is otherwise unchanged, so lifecycle-path requirements are validated for regression rather than redesigned.
- The GitHub label rename is an in-scope repository metadata change performed through GitHub after the code and workflow contracts are ready, while the current `symphony` label remains available for the active durable workflow until that transition can occur safely.
