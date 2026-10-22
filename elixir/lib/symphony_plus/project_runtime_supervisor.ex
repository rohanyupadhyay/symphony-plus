defmodule SymphonyPlus.ProjectRuntimeSupervisor do
  @moduledoc "Dynamically supervises one isolated runtime per registered project."
  use DynamicSupervisor

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
      nil -> DynamicSupervisor.start_child(supervisor, {SymphonyPlus.ProjectRuntime, registration: registration})
      pid -> {:ok, pid}
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
      pid -> SymphonyPlus.ProjectRuntime.idle?(pid)
    end
  end

  @spec snapshots(GenServer.server()) :: [map()]
  def snapshots(supervisor \\ __MODULE__) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.flat_map(fn
      {_id, pid, :worker, _modules} when is_pid(pid) -> [SymphonyPlus.ProjectRuntime.snapshot(pid)]
      _ -> []
    end)
    |> Enum.sort_by(& &1.registration.id)
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
          case SymphonyPlus.Orchestrator.snapshot(orchestrator, 15_000) do
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

  defp find_project(supervisor, project_id) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.find_value(fn
      {_id, pid, :worker, _modules} when is_pid(pid) ->
        if SymphonyPlus.ProjectRuntime.snapshot(pid).registration.id == project_id, do: pid

      _ ->
        nil
    end)
  end
end
