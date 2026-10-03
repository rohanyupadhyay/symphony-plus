# Contract: GitHub Pull Request Tracking Reference

## Producer

The GitHub Spec Kit workflow agent when it creates or updates the one pull request for an issue branch.

## Required output

The complete pull-request body MUST:

1. follow the target repository's `.github/pull_request_template.md`;
2. contain exactly one line in this form:

   ```text
   Tracks #<originating-issue-number>
   ```

3. derive `<originating-issue-number>` from `issue.id` in the active workflow context;
4. preserve that one line when updating the existing pull request; and
5. avoid every GitHub closing keyword (`close`, `closes`, `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, and `resolved`) for the originating issue.

The workflow MUST validate the complete body with the repository-required PR-body validation command before create or update.

## Observable outcomes

- The pull request description links to the originating issue.
- GitHub adds a reciprocal cross-reference visible from the originating issue.
- Repeated revisions do not add duplicate references.
- Closing or merging the pull request does not close the issue because of this reference.
- The separate merged-PR workflow remains the only automated path that closes the issue.

## Failure handling

If the body cannot satisfy both the repository template and this contract, the workflow MUST NOT create or update the pull request. It reports the validation failure and checkpoints the run as blocked with a concrete recovery action.
