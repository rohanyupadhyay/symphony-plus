defmodule SymphonyPlus.ProjectRuntimeSupervisor do
  @moduledoc "Dynamically supervises one isolated runtime per registered project."
  use DynamicSupervisor

  alias SymphonyPlus.Config.Schema.Updates
  alias SymphonyPlus.GitHub.MergeQueue
  alias SymphonyPlus.Orchestrator
  alias SymphonyPlus.ProjectRuntime

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    case Keyword.get(opts, :name, __MODULE__) do
      nil -> DynamicSupervisor.start_link(__MODULE__, opts)
      name -> DynamicSupervisor.start_link(__MODULE__, opts, name: name)
    end
  end

  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  @spec start_project(map(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_project(registration, opts \\ []) do
    supervisor = Keyword.get(opts, :supervisor, __MODULE__)

    case find_project(supervisor, registration.id) do
      nil ->
        options = [registration: registration, runtime_supervisor: supervisor]
        DynamicSupervisor.start_child(supervisor, {ProjectRuntime, options})

      pid ->
        {:ok, pid}
    end
  end

  @spec stop_project(String.t(), GenServer.server()) :: :ok
  def stop_project(project_id, supervisor \\ __MODULE__) do
    case find_project(supervisor, project_id) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(supervisor, pid)
    end
  end

  @spec project_idle?(String.t(), GenServer.server()) :: boolean()
  def project_idle?(project_id, supervisor \\ __MODULE__) do
    case find_project(supervisor, project_id) do
      nil -> true
      pid -> ProjectRuntime.idle?(pid)
    end
  end

  @spec snapshots(GenServer.server()) :: [map()]
  def snapshots(supervisor \\ __MODULE__) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.flat_map(fn
      {_id, pid, :worker, _modules} when is_pid(pid) -> [ProjectRuntime.snapshot(pid)]
      _ -> []
    end)
    |> Enum.sort_by(& &1.registration.id)
  end

  @doc "Selects one consistent installation update policy from registered projects."
  @spec update_policy(GenServer.server()) :: {:ok, Updates.t()} | {:error, :conflicting_update_policies}
  def update_policy(supervisor \\ __MODULE__) do
    policies =
      supervisor
      |> DynamicSupervisor.which_children()
      |> Enum.flat_map(fn
        {_id, pid, :worker, _modules} when is_pid(pid) ->
          case ProjectRuntime.configuration(pid) do
            %{updates: %{enabled: true} = policy} -> [policy]
            _ -> []
          end

        _ ->
          []
      end)
      |> Enum.uniq()

    case policies do
      [] -> {:ok, %Updates{}}
      [policy] -> {:ok, policy}
      _ -> {:error, :conflicting_update_policies}
    end
  end

  @spec begin_update_drain(GenServer.server()) :: {:ok, map()}
  def begin_update_drain(supervisor \\ __MODULE__) do
    tokens =
      Enum.reduce(snapshots(supervisor), %{}, fn
        %{orchestrator: pid}, acc when is_pid(pid) ->
          {:ok, token} = Orchestrator.begin_update_drain(pid)
          Map.put(acc, pid, token)

        _, acc ->
          acc
      end)

    {:ok, tokens}
  end

  @spec update_quiescent?(GenServer.server(), map()) :: boolean()
  def update_quiescent?(supervisor, tokens) do
    Enum.all?(snapshots(supervisor), fn
      %{orchestrator: pid, merge_queue: queue} when is_pid(pid) ->
        token =
          case Map.fetch(tokens, pid) do
            {:ok, value} -> value
            :error -> elem(Orchestrator.begin_update_drain(pid), 1)
          end

        Orchestrator.update_quiescent?(token, pid) and
          (is_nil(queue) or MergeQueue.idle?(queue))

      _ ->
        true
    end)
  end

  @spec cancel_update_drain(GenServer.server(), map()) :: :ok
  def cancel_update_drain(_supervisor, tokens) do
    Enum.each(tokens, fn {pid, token} ->
      if Process.alive?(pid), do: Orchestrator.cancel_update_drain(token, pid)
    end)

    :ok
  end

  @spec aggregate_snapshot(GenServer.server()) :: map()
  def aggregate_snapshot(supervisor \\ __MODULE__) do
    project_snapshots = snapshots(supervisor)

    project_data =
      Enum.map(project_snapshots, fn snapshot ->
        %{
          id: snapshot.registration.id,
          workflow_path: snapshot.registration.workflow_path,
          state: snapshot.state,
          failure_reason: snapshot.reason
        }
      end)

    active =
      Enum.flat_map(project_snapshots, fn
        %{registration: %{id: project_id}, orchestrator: orchestrator} when is_pid(orchestrator) ->
          case Orchestrator.snapshot(orchestrator, 15_000) do
            %{} = snapshot -> [{project_id, snapshot}]
            _ -> []
          end

        _ ->
          []
      end)

    classifications = [:running, :retrying, :blocked, :quota_waiting]

    lists =
      Map.new(classifications, fn classification ->
        entries =
          Enum.flat_map(active, fn {project_id, snapshot} ->
            snapshot
            |> Map.get(classification, [])
            |> Enum.map(&Map.put(&1, :project_id, project_id))
          end)

        {classification, entries}
      end)

    counts = Map.new(classifications, &{&1, length(Map.fetch!(lists, &1))})

    totals =
      Enum.reduce(active, %{input_tokens: 0, output_tokens: 0, total_tokens: 0, seconds_running: 0}, fn {_id, snapshot}, acc ->
        Enum.reduce(Map.keys(acc), acc, fn key, inner ->
          Map.update!(inner, key, &(&1 + get_in(snapshot, [:codex_totals, key])))
        end)
      end)

    max_concurrent_agents =
      Enum.reduce(project_snapshots, 0, fn snapshot, total ->
        total + (snapshot.max_concurrent_agents || 0)
      end)

    lists
    |> Map.merge(%{
      projects: project_data,
      counts: counts,
      codex_totals: totals,
      rate_limits: nil,
      max_concurrent_agents: max_concurrent_agents
    })
  end

  @spec request_refresh(GenServer.server()) :: map()
  def request_refresh(supervisor \\ __MODULE__) do
    projects =
      Enum.map(snapshots(supervisor), fn project ->
        result =
          if is_pid(project.orchestrator),
            do: Orchestrator.request_refresh(project.orchestrator),
            else: :unavailable

        case result do
          %{queued: true} = payload -> Map.put(payload, :project_id, project.registration.id)
          :unavailable -> %{project_id: project.registration.id, queued: false, reason: :unavailable}
        end
      end)

    %{
      queued: Enum.any?(projects, & &1.queued),
      coalesced: Enum.all?(projects, &Map.get(&1, :coalesced, false)),
      requested_at: DateTime.utc_now(),
      operations: ["poll", "reconcile"],
      projects: projects
    }
  end

  defp find_project(supervisor, project_id) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.find_value(fn
      {_id, pid, :worker, _modules} when is_pid(pid) ->
        if ProjectRuntime.snapshot(pid).registration.id == project_id, do: pid

      _ ->
        nil
    end)
  end
end
