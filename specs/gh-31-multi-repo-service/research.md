# Research: Single Multi-Repository Service

## Service ownership

**Decision**: A registered `ProjectRegistry` GenServer serializes registrations; a
`DynamicSupervisor` owns isolated project runtimes.

**Rationale**: Persistence can precede activation, concurrent UI/CLI requests become idempotent,
and one runtime crash cannot take down others.

**Alternatives considered**: Enlarging one orchestrator couples unrelated state; OS processes retain
the current problem; a database is unnecessary for a small local registry.

## Runtime configuration isolation

**Decision**: Pass loaded workflow/settings and stable project identity explicitly into each runtime,
removing project reads from the global application workflow path.

**Rationale**: Global application environment cannot safely represent simultaneous workflows while
explicit context preserves `SymphonyPlus.Config` as the typed boundary.

**Alternatives considered**: Process dictionary state is implicit; module cloning is speculative;
switching a global path is racy.

## Persistence and identity

**Decision**: Store `{version: 1, projects: [...]}` at
`elixir/tmp/symphony-plus/projects.json` by default, configurable for packaged installs. Persist only
a stable opaque ID and canonical absolute workflow path. Write/sync a same-directory temporary file
then rename atomically. Real canonical path is the uniqueness key; colliding workspace roots fail.

**Rationale**: This is installation-local and already ignored, remains inspectable, supports future
migrations, prevents partial reads, and enforces workspace safety before work begins.

**Alternatives considered**: Tracked YAML risks commits; DETS obscures recovery; XDG-only storage
does not meet the requested installation-local default; user names create a second identity authority.

## Invalid workflow recovery

**Decision**: Keep registrations unavailable with bounded safe reasons and retry validation on the
workflow polling cadence, logging only state transitions.

**Rationale**: Implements authorized Option A and isolates temporary failures.

**Alternatives considered**: Deletion loses intent; manual reload/restart impedes recovery.

## CLI and dashboard

**Decision**: Running-service mutations use local HTTP management endpoints; offline `list` may read
the registry, while offline mutations fail rather than creating split ownership. LiveView accepts an
explicit local workflow path (optionally enhanced by browser selection) and calls the same registry.

**Rationale**: The service remains the sole authority. Browsers cannot reliably expose host absolute
paths, and uploading/copying workflow content would violate repository ownership.

**Alternatives considered**: Direct CLI writes race; distributed Erlang and Unix sockets add
unnecessary transport/security complexity; a server-side filesystem browser expands exposure.
