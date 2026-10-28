defmodule SymphonyPlusWeb.Presenter do
  @moduledoc """
  Shared projections for the observability API and dashboard.
  """

  alias SymphonyPlus.{Config, Orchestrator, RuntimeStatus, StatusDashboard, Workspace}

  @spec state_payload(GenServer.name(), timeout()) :: map()
  def state_payload(orchestrator, snapshot_timeout_ms) do
    generated_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    case snapshot(orchestrator, snapshot_timeout_ms) do
      %{} = snapshot ->
        snapshot = RuntimeStatus.project(snapshot)

        %{
          generated_at: generated_at,
          counts: %{
            running: snapshot.counts.running,
            retrying: snapshot.counts.retrying,
            blocked: snapshot.counts.blocked,
            quota_waiting: snapshot.counts.quota_waiting
          },
          running: Enum.map(snapshot.running, &running_entry_payload/1),
          retrying: Enum.map(snapshot.retrying, &retry_entry_payload/1),
          blocked: Enum.map(Map.get(snapshot, :blocked, []), &blocked_entry_payload/1),
          quota_waiting: Enum.map(Map.get(snapshot, :quota_waiting, []), &quota_wait_entry_payload/1),
          codex_totals: snapshot.codex_totals,
          rate_limits: snapshot.rate_limits,
          update: snapshot.update
        }
        |> maybe_put_projects(orchestrator)

      :timeout ->
        %{generated_at: generated_at, error: %{code: "snapshot_timeout", message: "Snapshot timed out"}}

      :unavailable ->
        if orchestrator == SymphonyPlus.Orchestrator,
          do: empty_payload(generated_at),
          else: %{generated_at: generated_at, error: %{code: "snapshot_unavailable", message: "Snapshot unavailable"}}
    end
  end

  defp empty_payload(generated_at) do
    %{
      generated_at: generated_at,
      projects: project_payloads(SymphonyPlus.Orchestrator),
      counts: %{running: 0, retrying: 0, blocked: 0, quota_waiting: 0},
      running: [],
      retrying: [],
      blocked: [],
      quota_waiting: [],
      codex_totals: %{input_tokens: 0, output_tokens: 0, total_tokens: 0, seconds_running: 0},
      rate_limits: nil
    }
  end

  defp project_payloads(orchestrator) do
    if orchestrator == SymphonyPlus.Orchestrator and Process.whereis(SymphonyPlus.ProjectRuntimeSupervisor) do
      SymphonyPlus.ProjectRuntimeSupervisor.snapshots()
      |> Enum.map(fn snapshot ->
        %{
          id: snapshot.registration.id,
          workflow_path: snapshot.registration.workflow_path,
          state: snapshot.state,
          failure_reason: snapshot.reason
        }
      end)
    else
      []
    end
  end

  defp maybe_put_projects(payload, orchestrator) do
    if orchestrator == SymphonyPlus.Orchestrator,
      do: Map.put(payload, :projects, project_payloads(orchestrator)),
      else: payload
  end

  @spec issue_payload(String.t(), GenServer.name(), timeout()) ::
          {:ok, map()} | {:error, :issue_not_found | :ambiguous_issue}
  def issue_payload(issue_identifier, orchestrator, snapshot_timeout_ms),
    do: issue_payload(issue_identifier, orchestrator, snapshot_timeout_ms, nil)

  @spec issue_payload(String.t(), GenServer.name(), timeout(), String.t() | nil) ::
          {:ok, map()} | {:error, :issue_not_found | :ambiguous_issue}
  def issue_payload(issue_identifier, orchestrator, snapshot_timeout_ms, project_id) when is_binary(issue_identifier) do
    case snapshot(orchestrator, snapshot_timeout_ms) do
      %{} = snapshot ->
        snapshot = RuntimeStatus.project(snapshot)

        if is_nil(project_id) and length(project_ids_for_issue(snapshot, issue_identifier)) > 1 do
          {:error, :ambiguous_issue}
        else
          snapshot
          |> filter_project_snapshot(project_id)
          |> issue_from_snapshot(issue_identifier)
        end

      _ ->
        {:error, :issue_not_found}
    end
  end

  defp project_ids_for_issue(snapshot, identifier) do
    [:running, :retrying, :blocked, :quota_waiting]
    |> Enum.flat_map(&Map.get(snapshot, &1, []))
    |> Enum.filter(&(&1.identifier == identifier))
    |> Enum.map(&Map.get(&1, :project_id))
    |> Enum.uniq()
  end

  defp filter_project_snapshot(snapshot, project_id) do
    Map.new(snapshot, fn
      {key, entries} when key in [:running, :retrying, :blocked, :quota_waiting] ->
        {key, Enum.filter(entries, &(is_nil(project_id) or Map.get(&1, :project_id) == project_id))}

      pair ->
        pair
    end)
  end

  defp issue_from_snapshot(snapshot, issue_identifier) do
    running = Enum.find(snapshot.running, &(&1.identifier == issue_identifier))
    retry = Enum.find(snapshot.retrying, &(&1.identifier == issue_identifier))
    blocked = Enum.find(Map.get(snapshot, :blocked, []), &(&1.identifier == issue_identifier))
    quota_wait = Enum.find(Map.get(snapshot, :quota_waiting, []), &(&1.identifier == issue_identifier))

    if is_nil(running) and is_nil(retry) and is_nil(blocked) and is_nil(quota_wait) do
      {:error, :issue_not_found}
    else
      payload = issue_payload_body(issue_identifier, running, retry, blocked, quota_wait)
      {:ok, with_project_identity(payload, running || retry || blocked || quota_wait)}
    end
  end

  @spec refresh_payload(GenServer.name()) :: {:ok, map()} | {:error, :unavailable}
  def refresh_payload(orchestrator) do
    result =
      if orchestrator == SymphonyPlus.Orchestrator and Process.whereis(SymphonyPlus.ProjectRuntimeSupervisor),
        do: SymphonyPlus.ProjectRuntimeSupervisor.request_refresh(),
        else: Orchestrator.request_refresh(orchestrator)

    case result do
      :unavailable ->
        {:error, :unavailable}

      payload ->
        {:ok, Map.update!(payload, :requested_at, &DateTime.to_iso8601/1)}
    end
  end

  defp snapshot(SymphonyPlus.Orchestrator, _timeout) do
    if Process.whereis(SymphonyPlus.ProjectRuntimeSupervisor) do
      SymphonyPlus.ProjectRuntimeSupervisor.aggregate_snapshot()
    else
      :unavailable
    end
  end

  defp snapshot(orchestrator, timeout), do: Orchestrator.snapshot(orchestrator, timeout)

  defp issue_payload_body(issue_identifier, running, retry, blocked, quota_wait) do
    %{
      issue_identifier: issue_identifier,
      issue_id: issue_id_from_entries(running, retry, blocked, quota_wait),
      status: issue_status(running, retry, blocked, quota_wait),
      workspace: %{
        path: workspace_path(issue_identifier, running, retry, blocked, quota_wait),
        host: workspace_host(running, retry, blocked, quota_wait)
      },
      attempts: %{
        restart_count: restart_count(retry),
        current_retry_attempt: retry_attempt(retry)
      },
      running: running && running_issue_payload(running),
      retry: retry && retry_issue_payload(retry),
      blocked: blocked && blocked_issue_payload(blocked),
      quota_wait: quota_wait && quota_wait_entry_payload(quota_wait),
      logs: %{
        codex_session_logs: []
      },
      recent_events: recent_events_payload(running || blocked),
      last_error: (blocked && blocked.error) || (retry && retry.error),
      tracked: %{}
    }
  end

  defp issue_id_from_entries(running, retry, blocked, quota_wait),
    do:
      (running && running.issue_id) || (retry && retry.issue_id) || (blocked && blocked.issue_id) ||
        (quota_wait && quota_wait.issue_id)

  defp restart_count(retry), do: max(retry_attempt(retry) - 1, 0)
  defp retry_attempt(nil), do: 0
  defp retry_attempt(retry), do: retry.attempt || 0

  defp issue_status(_running, _retry, blocked, _quota_wait) when not is_nil(blocked), do: "blocked"
  defp issue_status(_running, _retry, nil, quota_wait) when not is_nil(quota_wait), do: "quota_waiting"
  defp issue_status(_running, retry, nil, nil) when not is_nil(retry), do: "retrying"
  defp issue_status(running, nil, nil, nil) when not is_nil(running), do: "running"

  defp running_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      issue_url: Map.get(entry, :issue_url),
      state: entry.state,
      worker_host: Map.get(entry, :worker_host),
      workspace_path: Map.get(entry, :workspace_path),
      session_id: entry.session_id,
      turn_count: Map.get(entry, :turn_count, 0),
      last_event: entry.last_codex_event,
      last_message: summarize_message(entry.last_codex_message),
      started_at: iso8601(entry.started_at),
      last_event_at: iso8601(entry.last_codex_timestamp),
      tokens: %{
        input_tokens: entry.codex_input_tokens,
        output_tokens: entry.codex_output_tokens,
        total_tokens: entry.codex_total_tokens
      }
    }
    |> with_project_identity(entry)
  end

  defp retry_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      issue_url: Map.get(entry, :issue_url),
      attempt: entry.attempt,
      due_at: due_at_iso8601(entry.due_in_ms),
      error: entry.error,
      worker_host: Map.get(entry, :worker_host),
      workspace_path: Map.get(entry, :workspace_path)
    }
    |> with_project_identity(entry)
  end

  defp blocked_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      issue_url: Map.get(entry, :issue_url),
      state: Map.get(entry, :state),
      error: Map.get(entry, :error),
      reason: Map.get(entry, :reason, Map.get(entry, :error)),
      quota_context: Map.get(entry, :quota_context),
      worker_host: Map.get(entry, :worker_host),
      workspace_path: Map.get(entry, :workspace_path),
      session_id: Map.get(entry, :session_id),
      blocked_at: iso8601(Map.get(entry, :blocked_at) || Map.get(entry, :updated_at)),
      last_event: Map.get(entry, :last_codex_event),
      last_message: summarize_message(Map.get(entry, :last_codex_message)),
      last_event_at: iso8601(Map.get(entry, :last_codex_timestamp))
    }
    |> with_project_identity(entry)
  end

  defp quota_wait_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      issue_url: Map.get(entry, :issue_url),
      status: entry.status,
      harness: entry.harness,
      pool_key: entry.pool_key,
      renewal_at: iso8601(entry.renewal_at),
      next_recheck_at: iso8601(entry.next_recheck_at),
      native_context_available: entry.native_context_available,
      workspace_path: entry.workspace_path,
      worker_host: entry.worker_host,
      last_outcome: entry.last_outcome,
      updated_at: iso8601(entry.updated_at),
      timing_cue: Map.get(entry, :timing_cue)
    }
    |> with_project_identity(entry)
  end

  defp with_project_identity(payload, entry) do
    if Map.has_key?(entry, :project_id), do: Map.put(payload, :project_id, entry.project_id), else: payload
  end

  defp running_issue_payload(running) do
    %{
      worker_host: Map.get(running, :worker_host),
      workspace_path: Map.get(running, :workspace_path),
      session_id: running.session_id,
      turn_count: Map.get(running, :turn_count, 0),
      state: running.state,
      started_at: iso8601(running.started_at),
      last_event: running.last_codex_event,
      last_message: summarize_message(running.last_codex_message),
      last_event_at: iso8601(running.last_codex_timestamp),
      tokens: %{
        input_tokens: running.codex_input_tokens,
        output_tokens: running.codex_output_tokens,
        total_tokens: running.codex_total_tokens
      }
    }
  end

  defp retry_issue_payload(retry) do
    %{
      attempt: retry.attempt,
      due_at: due_at_iso8601(retry.due_in_ms),
      error: retry.error,
      worker_host: Map.get(retry, :worker_host),
      workspace_path: Map.get(retry, :workspace_path)
    }
  end

  defp blocked_issue_payload(blocked) do
    %{
      worker_host: Map.get(blocked, :worker_host),
      workspace_path: Map.get(blocked, :workspace_path),
      session_id: Map.get(blocked, :session_id),
      state: Map.get(blocked, :state),
      error: Map.get(blocked, :error),
      reason: Map.get(blocked, :reason),
      quota_context: Map.get(blocked, :quota_context),
      blocked_at: iso8601(Map.get(blocked, :blocked_at) || Map.get(blocked, :updated_at)),
      last_event: Map.get(blocked, :last_codex_event),
      last_message: summarize_message(Map.get(blocked, :last_codex_message)),
      last_event_at: iso8601(Map.get(blocked, :last_codex_timestamp))
    }
  end

  defp workspace_path(issue_identifier, running, retry, blocked, quota_wait) do
    (running && Map.get(running, :workspace_path)) ||
      (retry && Map.get(retry, :workspace_path)) ||
      (blocked && Map.get(blocked, :workspace_path)) ||
      (quota_wait && Map.get(quota_wait, :workspace_path)) ||
      Path.join(Config.settings!().workspace.root, Workspace.workspace_key(issue_identifier))
  end

  defp workspace_host(running, retry, blocked, quota_wait) do
    (running && Map.get(running, :worker_host)) ||
      (retry && Map.get(retry, :worker_host)) ||
      (blocked && Map.get(blocked, :worker_host)) ||
      (quota_wait && Map.get(quota_wait, :worker_host))
  end

  defp recent_events_payload(nil), do: []

  defp recent_events_payload(entry) do
    [
      %{
        at: iso8601(Map.get(entry, :last_codex_timestamp)),
        event: Map.get(entry, :last_codex_event),
        message: summarize_message(Map.get(entry, :last_codex_message))
      }
    ]
    |> Enum.reject(&is_nil(&1.at))
  end

  defp summarize_message(nil), do: nil
  defp summarize_message(message), do: StatusDashboard.humanize_codex_message(message)

  defp due_at_iso8601(due_in_ms) when is_integer(due_in_ms) do
    DateTime.utc_now()
    |> DateTime.add(div(due_in_ms, 1_000), :second)
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp due_at_iso8601(_due_in_ms), do: nil

  defp iso8601(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp iso8601(_datetime), do: nil
end
