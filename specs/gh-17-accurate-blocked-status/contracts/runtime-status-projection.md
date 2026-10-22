# Runtime Status Projection Contract

## Purpose

Define the shared observable contract for terminal, `/api/v1/state`, `/api/v1/:issue_identifier`, and LiveView dashboard status.

## Classification

For each issue identity, the projection MUST emit no more than one primary status. When raw records overlap, precedence is:

1. blocked, including quota status `operator_blocked`;
2. recoverable quota-waiting;
3. retrying;
4. running.

The projection MUST derive summary counts and primary lists from the same normalized entries.

## Blocked contract

A blocked entry MUST expose primary status `blocked`; issue identity and safe tracker link when available; a one-line reason of at most 160 Unicode graphemes including any truncation marker, or the stable cue `Operator action required` when no reason is available; available session, timestamp, workspace, and worker context; supplementary tracker state; and quota context when failed quota resume caused the block.

A quota-derived block MUST NOT remain in the quota-waiting primary list or count.

## Recoverable quota contract

A recoverable quota entry MUST expose primary status `quota_waiting`, harness, pool, renewal or recheck time, native-context availability, and stable outcome. When neither renewal nor recheck timing is known, it MUST expose the stable cue `Renewal time unavailable`. It MUST remain distinct from retry backoff.

## Surface behavior

- The terminal dashboard MUST include blocked and quota-waiting sections using the shared terms.
- JSON state counts MUST equal corresponding array lengths.
- JSON issue detail `status` MUST equal the primary classification; incompatible detail objects MUST not both describe primary states.
- LiveView cards and rows MUST render the same classification and diagnostic values as JSON for the same snapshot.
- A normal PubSub update MUST replace counts and rows from one coherent snapshot.
- Snapshot timeout and unavailable responses retain the existing whole-snapshot error contract.

## Safety

Displayed reasons MUST collapse control characters and excess whitespace to one line, contain at most 160 Unicode graphemes including any truncation marker, and exclude credentials, prompts, raw provider payloads, and unnecessary output. HTML escaping remains the renderer's responsibility.

## Compatibility

Token totals, rate limits, running details, retry timing, refresh endpoints, and unavailable-state semantics remain unchanged except that duplicated issues no longer inflate or conflict with lifecycle status.
