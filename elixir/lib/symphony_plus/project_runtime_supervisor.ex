defmodule SymphonyPlus.ProjectRuntimeSupervisor do
  @moduledoc "Dynamically supervises one isolated runtime per registered project."
  use DynamicSupervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
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
