# Dashboard and Local Management API Contract

`GET /api/v1/state` adds `projects`, and every project-scoped issue row adds `project_id`. Project
summaries contain `id`, canonical `workflow_path`, `state`, and bounded `failure_reason`.

- `POST /api/v1/projects` with `{ "workflow_path": "/absolute/path" }`
- `DELETE /api/v1/projects/:project_id`

Success outcomes: `created`, `already_registered`, `removed`. Stable error codes:
`invalid_workflow`, `workspace_conflict`, `project_busy`, `registry_unavailable`,
`project_not_found`. Browser submissions retain CSRF protection; responses never echo workflow
content or raw exceptions.

LiveView adds a Projects section and healthy empty state. Its add form calls the same registry API;
removal is refused for non-idle projects. PubSub refreshes connected views after transitions.
