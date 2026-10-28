defmodule SymphonyPlus.ProjectRuntime do
  @moduledoc "Owns validation and lifecycle state for one registered project."
  use GenServer

  alias SymphonyPlus.Config.Schema
  alias SymphonyPlus.GitHub.MergeQueue
  alias SymphonyPlus.Orchestrator
  alias SymphonyPlus.UpdateManager

  @retry_ms 1_000
  @reason_limit 160

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    registration = Keyword.fetch!(opts, :registration)
    GenServer.start_link(__MODULE__, {registration, Keyword.get(opts, :runtime_supervisor, SymphonyPlus.ProjectRuntimeSupervisor)})
  end

  @spec snapshot(pid()) :: map()
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  @spec configuration(pid()) :: Schema.t() | nil
  def configuration(pid), do: GenServer.call(pid, :configuration)

  @spec idle?(pid()) :: boolean()
  def idle?(pid) do
    case snapshot(pid) do
      %{orchestrator: orchestrator} = project when is_pid(orchestrator) ->
        case SymphonyPlus.Orchestrator.snapshot(orchestrator, 15_000) do
          %{counts: counts} ->
            Enum.all?([:running, :retrying, :blocked, :quota_waiting], &(Map.get(counts, &1, 0) == 0)) and queue_idle?(project.merge_queue)

          _ ->
            false
        end

      %{state: :unavailable} ->
        true

      _ ->
        false
    end
  end

  @impl true
  def init({registration, runtime_supervisor}) do
    Process.flag(:trap_exit, true)
    send(self(), :validate)

    {:ok,
     %{
       registration: registration,
       runtime_supervisor: runtime_supervisor,
       state: :starting,
       reason: nil,
       workflow: nil,
       settings: nil,
       stamp: nil,
       task_supervisor: nil,
       orchestrator: nil,
       merge_queue: nil,
       reload_drain: nil,
       reload_request: nil,
       reload_quiescent: false
     }}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    snapshot =
      state
      |> Map.take([:registration, :state, :reason, :orchestrator, :merge_queue])
      |> Map.put(:max_concurrent_agents, state.settings && state.settings.agent.max_concurrent_agents)

    {:reply, snapshot, state}
  end

  def handle_call(:configuration, _from, state), do: {:reply, state.settings, state}

  @impl true
  def handle_info(:validate, state) do
    state = validate(state)
    Process.send_after(self(), :validate, @retry_ms)
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, state) when pid in [state.task_supervisor, state.orchestrator, state.merge_queue] do
    state = stop_runtime(state)
    safe = safe_reason(reason)
    Process.send_after(self(), :validate, @retry_ms)
    {:noreply, %{state | state: :unavailable, reason: safe}}
  end

  def handle_info({:EXIT, _pid, _reason}, state), do: {:noreply, state}

  def handle_info(message, %{reload_request: {request_id, operation}} = state) do
    case :gen_server.check_response(message, request_id) do
      {:reply, reply} ->
        state = finish_reload_request(%{state | reload_request: nil}, operation, reply)
        state = if operation != :quiescence or reply, do: validate(state), else: state
        {:noreply, state}

      {:error, {reason, _server}} ->
        {:noreply, activation_failed(state, reason)}

      :no_reply ->
        {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

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
        if is_pid(state.orchestrator) and Process.alive?(state.orchestrator) do
          state
          |> cancel_reload_drain()
          |> Map.merge(%{state: :active, reason: safe_reason(reason)})
        else
          %{state | state: :unavailable, reason: safe_reason(reason)}
        end
    end
  end

  defp activate(%{orchestrator: orchestrator, stamp: stamp} = state, workflow, settings, stamp)
       when is_pid(orchestrator) do
    state
    |> cancel_reload_drain()
    |> Map.merge(%{state: :active, reason: nil, workflow: workflow, settings: settings})
  end

  defp activate(%{orchestrator: orchestrator} = state, workflow, settings, stamp) when is_pid(orchestrator) do
    if routing_changed?(state.settings, settings) do
      state = %{state | reason: "Waiting for retained work before changing tracker or workspace"}

      cond do
        state.reload_request != nil ->
          state

        state.reload_drain == nil ->
          request_reload(state, :begin, {:begin_update_drain, :reconfiguration})

        state.reload_quiescent and queue_idle?(state.merge_queue) ->
          state |> stop_runtime() |> activate(workflow, settings, stamp)

        state.reload_quiescent ->
          %{state | reload_quiescent: false}

        true ->
          request_reload(state, :quiescence, {:update_quiescent?, state.reload_drain})
      end
    else
      context = project_context(state, workflow, settings)
      :ok = Orchestrator.update_project_context(orchestrator, context)
      :ok = MergeQueue.update_project_context(state.merge_queue, context)

      state
      |> cancel_reload_drain()
      |> Map.merge(%{state: :active, reason: nil, workflow: workflow, settings: settings, stamp: stamp})
    end
  end

  defp activate(state, workflow, settings, stamp) do
    if UpdateManager.draining?(state.runtime_supervisor) do
      %{state | state: :unavailable, reason: "Installation update is draining; project activation deferred"}
    else
      start_runtime(state, workflow, settings, stamp)
    end
  end

  defp start_runtime(state, workflow, settings, stamp) do
    context = project_context(state, workflow, settings)
    state = %{state | workflow: workflow, settings: settings}

    case Task.Supervisor.start_link() do
      {:ok, task_supervisor} ->
        start_merge_queue(%{state | task_supervisor: task_supervisor}, context, stamp)

      {:error, reason} ->
        activation_failed(state, reason)
    end
  end

  defp start_merge_queue(state, context, stamp) do
    case MergeQueue.start_link(name: nil, project_context: context) do
      {:ok, queue} -> start_orchestrator(%{state | merge_queue: queue}, context, stamp)
      {:error, reason} -> activation_failed(state, reason)
    end
  end

  defp start_orchestrator(state, context, stamp) do
    case Orchestrator.start_link(name: nil, task_supervisor: state.task_supervisor, project_context: context) do
      {:ok, orchestrator} ->
        %{state | state: :active, reason: nil, orchestrator: orchestrator, stamp: stamp, reload_drain: nil}

      {:error, reason} ->
        activation_failed(state, reason)
    end
  end

  defp activation_failed(state, reason),
    do: state |> stop_runtime() |> Map.merge(%{state: :unavailable, reason: safe_reason(reason), stamp: nil})

  defp project_context(state, workflow, settings) do
    %{
      project_id: state.registration.id,
      workflow: workflow,
      settings: settings,
      workflow_path: state.registration.workflow_path
    }
  end

  defp routing_changed?(previous, next),
    do:
      {previous.tracker.kind, previous.tracker.provider, previous.workspace.root, previous.worker.ssh_hosts} !=
        {next.tracker.kind, next.tracker.provider, next.workspace.root, next.worker.ssh_hosts}

  defp cancel_reload_drain(%{reload_request: request} = state) when request != nil, do: state
  defp cancel_reload_drain(%{reload_drain: nil} = state), do: state

  defp cancel_reload_drain(state),
    do: request_reload(state, :cancel, {:cancel_update_drain, state.reload_drain})

  # Keep the pending request until its reply: a timed-out begin call can still
  # acquire a drain, so abandoning its reply would lose the cancellation token.
  defp request_reload(state, operation, request) do
    request_id = :gen_server.send_request(state.orchestrator, request)
    %{state | reload_request: {request_id, operation}, reload_quiescent: false}
  end

  defp finish_reload_request(state, :begin, {:ok, token}), do: %{state | reload_drain: token}
  defp finish_reload_request(state, :quiescence, quiet), do: %{state | reload_quiescent: quiet}
  defp finish_reload_request(state, :cancel, _reply), do: %{state | reload_drain: nil}

  defp stop_runtime(state) do
    if state.reload_request do
      {request_id, _operation} = state.reload_request
      _ = :gen_server.receive_response(request_id, 0)
    end

    Enum.each([state.orchestrator, state.merge_queue, state.task_supervisor], fn
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          try do
            GenServer.stop(pid, :shutdown, 5_000)
          catch
            :exit, _reason -> Process.exit(pid, :kill)
          end
        end

      _ ->
        :ok
    end)

    %{
      state
      | orchestrator: nil,
        task_supervisor: nil,
        merge_queue: nil,
        reload_drain: nil,
        reload_request: nil,
        reload_quiescent: false
    }
  end

  defp queue_idle?(nil), do: true
  defp queue_idle?(queue), do: MergeQueue.idle?(queue)

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
