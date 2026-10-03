# Quickstart: Validate PR-to-Issue Tracking

## Prerequisites

- Elixir 1.19 and OTP 28 through `mise`
- Dependencies installed in `elixir/`
- A disposable GitHub repository configured for the reusable Spec Kit workflow for the optional live check

## 1. Run the focused workflow-template regression

```bash
cd elixir
mise exec -- mix test test/symphony_elixir/github_launcher_test.exs
```

Expected: the reusable workflow contract requires one `Tracks #{{ issue.id }}` reference, rejects auto-closing wording, and retains explicit merged-PR issue closure.

## 2. Validate a representative PR body

Create a temporary body by copying `.github/pull_request_template.md`, replacing all placeholders, and adding one `Tracks #10` line without a closing keyword. Then run:

```bash
cd elixir
mise exec -- mix pr_body.check --file /absolute/path/to/body.md
```

Expected: `PR body format OK`, and a text search finds exactly one `Tracks #10` occurrence and no closing keyword for issue 10.

## 3. Run the repository quality gate

```bash
make -C elixir all
```

Expected: formatting, public-spec validation, Credo, coverage, and Dialyzer pass. Report dependency advisory output separately if the gate emits it.

## 4. Optional disposable GitHub validation

1. Label a disposable issue for Symphony and advance it through implementation approval.
2. Let Symphony create its pull request.
3. Inspect the PR body and issue timeline: each must provide a direct link to the other, and the PR body must contain one `Tracks #<issue>` line.
4. Update the same PR through a revision and confirm the reference remains singular.
5. Close the PR without merging and confirm the issue remains open.
6. In a separate disposable run, merge the PR and confirm the issue closes only when the workflow processes the merged-PR event.

Do not use a production issue for this validation.
