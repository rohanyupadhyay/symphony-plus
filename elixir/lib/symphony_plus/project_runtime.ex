defmodule SymphonyPlus.ProjectRuntime do
  @moduledoc "Owns validation and lifecycle state for one registered project."
  use GenServer

  alias SymphonyPlus.Config.Schema

  @retry_ms 1_000
  @reason_limit 160

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    registration = Keyword.fetch!(opts, :registration)
    GenServer.start_link(__MODULE__, registration)
  end

  @spec snapshot(pid()) :: map()
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  @spec idle?(pid()) :: boolean()
  def idle?(pid) do
    case snapshot(pid) do
      %{orchestrator: orchestrator} when is_pid(orchestrator) ->
        case SymphonyPlus.Orchestrator.snapshot(orchestrator, 15_000) do
          %{counts: counts} -> Enum.all?([:running, :retrying, :blocked, :quota_waiting], &(Map.get(counts, &1, 0) == 0))
          _ -> false
        end

      %{state: :unavailable} ->
        true

      _ ->
        false
    end
  end

  @impl true
  def init(registration) do
    Process.flag(:trap_exit, true)
    send(self(), :validate)

    {:ok,
     %{
       registration: registration,
       state: :starting,
       reason: nil,
       workflow: nil,
       settings: nil,
       stamp: nil,
       task_supervisor: nil,
       orchestrator: nil
     }}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    snapshot =
      state
      |> Map.take([:registration, :state, :reason, :orchestrator])
      |> Map.put(:max_concurrent_agents, state.settings && state.settings.agent.max_concurrent_agents)

    {:reply, snapshot, state}
  end

  @impl true
  def handle_info(:validate, state) do
    state = validate(state)
    Process.send_after(self(), :validate, @retry_ms)
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, state) when pid in [state.task_supervisor, state.orchestrator] do
    state = stop_runtime(state)
    safe = safe_reason(reason)
    Process.send_after(self(), :validate, @retry_ms)
    {:noreply, %{state | state: :unavailable, reason: safe}}
  end

  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    _ = stop_runtime(state)
    :ok
  end

  defp validate(state) do
    path = state.registration.workflow_path

    with {:ok, workflow} <- SymphonyPlus.Workflow.load(path),
         {:ok, settings} <- Schema.parse(workflow.config),
         :ok <- SymphonyPlus.Config.validate_settings(settings),
         {:ok, stamp} <- workflow_stamp(path) do
      activate(state, workflow, settings, stamp)
    else
      {:error, reason} ->
        state = stop_runtime(state)
        %{state | state: :unavailable, reason: safe_reason(reason), workflow: nil, settings: nil, stamp: nil}
    end
  end

  defp activate(%{orchestrator: orchestrator, stamp: stamp} = state, workflow, settings, stamp)
       when is_pid(orchestrator) do
    %{state | state: :active, reason: nil, workflow: workflow, settings: settings}
  end

  defp activate(state, workflow, settings, stamp) do
    state = stop_runtime(state)

    context = %{
      project_id: state.registration.id,
      workflow: workflow,
      settings: settings,
      workflow_path: state.registration.workflow_path
    }

    with {:ok, task_supervisor} <- Task.Supervisor.start_link(),
         {:ok, orchestrator} <-
           SymphonyPlus.Orchestrator.start_link(
             name: nil,
             task_supervisor: task_supervisor,
             project_context: context
           ) do
      %{
        state
        | state: :active,
          reason: nil,
          workflow: workflow,
          settings: settings,
          stamp: stamp,
          task_supervisor: task_supervisor,
          orchestrator: orchestrator
      }
    else
      {:error, reason} ->
        stop_runtime(state)
        |> Map.merge(%{state: :unavailable, reason: safe_reason(reason), workflow: nil, settings: nil, stamp: nil})
    end
  end

  defp stop_runtime(state) do
    Enum.each([state.orchestrator, state.task_supervisor], fn
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: Process.exit(pid, :shutdown)

      _ ->
        :ok
    end)

    %{state | orchestrator: nil, task_supervisor: nil}
  end

  defp workflow_stamp(path) do
    with {:ok, stat} <- File.stat(path, time: :posix),
         {:ok, content} <- File.read(path) do
      {:ok, {stat.mtime, stat.size, :erlang.phash2(content)}}
    end
  end

  defp safe_reason(reason) do
    reason |> inspect() |> String.replace(~r/\s+/, " ") |> String.slice(0, @reason_limit)
  end
end
