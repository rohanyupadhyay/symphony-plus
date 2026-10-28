defmodule SymphonyPlus.UpdateManager do
  @moduledoc "Owns automatic update scheduling, admission, and activation handoff."

  use GenServer
  require Logger

  alias SymphonyPlus.{Config, Orchestrator, ProjectRuntimeSupervisor, SourceUpdate}
  alias SymphonyPlus.GitHub.MergeQueue

  @states [:disabled, :current, :checking, :preparing, :pending, :draining, :activating, :blocked, :failed]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))

  @spec status(GenServer.server()) :: map()
  def status(server \\ __MODULE__) do
    available? = if is_pid(server), do: Process.alive?(server), else: not is_nil(Process.whereis(server))
    if available?, do: GenServer.call(server, :status), else: empty_status(:disabled)
  end

  @spec check_now(GenServer.server()) :: :ok
  def check_now(server \\ __MODULE__), do: GenServer.cast(server, :check)

  @spec draining?(GenServer.server()) :: boolean()
  def draining?(runtime_supervisor \\ ProjectRuntimeSupervisor),
    do: :persistent_term.get({__MODULE__, :draining, runtime_supervisor}, false)

  @impl true
  def init(opts) do
    registry = Keyword.get(opts, :runtime_supervisor)

    if registry do
      :persistent_term.erase({__MODULE__, :draining, registry})
      {:ok, previous} = ProjectRuntimeSupervisor.begin_update_drain(registry)
      :ok = ProjectRuntimeSupervisor.cancel_update_drain(registry, previous)
    end

    state = %{
      policy: Keyword.get_lazy(opts, :policy, fn -> configured_policy(registry) end),
      runtime_supervisor: registry,
      reload_config?: not Keyword.has_key?(opts, :policy),
      source: Keyword.get(opts, :source, SourceUpdate),
      orchestrator: Keyword.get(opts, :orchestrator, Orchestrator),
      merge_queue: Keyword.get(opts, :merge_queue, MergeQueue),
      activator: Keyword.get(opts, :activator, &activate/3),
      stopper: Keyword.get(opts, :stopper, fn -> System.stop(0) end),
      timer: nil,
      checking: false,
      drain_token: nil,
      candidate: nil,
      attempted: MapSet.new(),
      status: empty_status(:disabled)
    }

    {:ok, schedule(reconcile_policy(state), 0)}
  end

  @impl true
  def terminate(_reason, state) do
    if state.runtime_supervisor do
      :persistent_term.erase({__MODULE__, :draining, state.runtime_supervisor})
      if state.drain_token && state.status.state != :activating, do: cancel_runtime_drain(state)
    end

    :ok
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  @impl true
  def handle_cast(:check, %{checking: true} = state), do: {:noreply, state}
  def handle_cast(:check, state), do: {:noreply, run_check(reconcile_policy(state))}

  @impl true
  def handle_info(:check, %{checking: true} = state), do: {:noreply, state}
  def handle_info(:check, state), do: {:noreply, run_check(reconcile_policy(%{state | timer: nil}))}
  def handle_info(:admit, state), do: {:noreply, maybe_admit(state)}

  defp run_check(%{policy: %{enabled: false}, status: %{last_outcome: "configuration_conflict"}} = state), do: schedule(state, 1_000)

  defp run_check(%{policy: %{enabled: false}} = state),
    do: schedule(%{state | status: empty_status(:disabled)}, 1_000)

  defp run_check(state) do
    state = put_status(state, :checking, "checking")
    root = state.policy.installation_root

    result = state.source.discover(root, state.policy.remote)
    checked = DateTime.utc_now()
    Logger.info("update check outcome=#{check_outcome(result)} installation=#{root}")

    state =
      case result do
        {:ok, :current} -> %{state | status: status(:current, revision(root), nil, checked, "current", nil)}
        {:ok, candidate} -> handle_candidate(%{state | status: %{state.status | last_checked_at: checked}}, candidate)
        {:error, reason} -> fail(state, :failed, "check_failed", reason)
      end

    schedule(%{state | checking: false}, state.policy.interval_ms)
  end

  defp handle_candidate(state, candidate) do
    cond do
      MapSet.member?(state.attempted, candidate.revision) ->
        fail(state, :blocked, "already_attempted", :candidate_already_attempted)

      state.candidate && state.candidate.revision == candidate.revision ->
        state

      true ->
        Logger.info("update candidate outcome=detected installation=#{state.policy.installation_root} revision=#{candidate.revision}")
        state = put_status(%{state | candidate: Map.merge(candidate, %{preparation_state: :preparing, attempted: false})}, :preparing, "preparing")

        case state.source.prepare(state.policy.installation_root, candidate, state.policy.prepare_command) do
          {:ok, path} -> begin_drain(%{state | candidate: Map.merge(state.candidate, %{prepared_path: path, preparation_state: :ready})})
          {:error, reason} -> fail(state, :failed, "preparation_failed", reason)
        end
    end
  end

  defp begin_drain(state) do
    {:ok, token} = begin_runtime_drain(state)
    Logger.info("update drain outcome=started installation=#{state.policy.installation_root} revision=#{state.candidate.revision}")
    Process.send_after(self(), :admit, 100)
    put_status(%{state | drain_token: token}, :draining, "waiting for admitted work to finish")
  end

  defp maybe_admit(%{drain_token: nil} = state), do: state

  defp maybe_admit(state) do
    if runtime_quiescent?(state) do
      admit_current_candidate(state)
    else
      Process.send_after(self(), :admit, 250)
      state
    end
  end

  defp admit_current_candidate(state) do
    if state.source.candidate_still_current?(state.policy.installation_root, state.policy.remote, state.candidate) do
      activate_candidate(state)
    else
      abandon(state, :candidate_moved)
    end
  end

  defp activate_candidate(state) do
    revision = state.candidate.revision

    state =
      put_status(
        %{state | attempted: MapSet.put(state.attempted, revision)},
        :activating,
        "activation handoff started"
      )

    case state.activator.(state.policy, state.candidate, System.pid()) do
      :ok ->
        Logger.info("update activation outcome=handoff_started installation=#{state.policy.installation_root} revision=#{revision}")
        state.stopper.()
        state

      {:error, reason} ->
        Logger.warning("update activation outcome=blocked installation=#{state.policy.installation_root} revision=#{revision}")
        fail(state, :blocked, "activation_failed", reason)
    end
  end

  defp reconcile_policy(state) do
    if state.reload_config? do
      reconcile_configured_policy(state)
    else
      state
    end
  end

  defp reconcile_configured_policy(state) do
    case policy_result(state.runtime_supervisor) do
      {:ok, policy} ->
        apply_policy(state, policy)

      {:error, reason} ->
        if state.drain_token, do: cancel_runtime_drain(state)

        %{
          state
          | policy: %Config.Schema.Updates{},
            drain_token: nil,
            candidate: nil,
            status: status(:blocked, nil, nil, DateTime.utc_now(), "configuration_conflict", inspect(reason))
        }
    end
  end

  defp apply_policy(state, policy) do
    if state.policy.enabled and not policy.enabled and state.drain_token,
      do: cancel_runtime_drain(state)

    %{
      state
      | policy: policy,
        drain_token: if(policy.enabled, do: state.drain_token, else: nil),
        candidate: if(policy.enabled, do: state.candidate, else: nil)
    }
  end

  defp abandon(state, reason) do
    if state.drain_token, do: cancel_runtime_drain(state)
    fail(%{state | drain_token: nil, candidate: nil}, :failed, "candidate_abandoned", reason)
  end

  defp activate(policy, candidate, pid) do
    script = Path.join(policy.installation_root, "elixir/scripts/apply-source-update")
    launch_args = Application.get_env(:symphony_plus, :launch_arguments, [])
    args_path = Path.join(policy.installation_root, ".git/symphony-plus-restart.args")
    :ok = File.write(args_path, Enum.map_join(launch_args, "", &(&1 <> <<0>>)))
    :ok = File.chmod(args_path, 0o600)

    args = [
      policy.installation_root,
      candidate.prepared_path,
      candidate.revision,
      to_string(pid),
      policy.launcher_command,
      args_path
    ]

    env =
      if launch_args == [] do
        []
      else
        [
          {"SYMPHONY_PLUS_RESTART_ARGUMENTS", Jason.encode!(launch_args)},
          {"SYMPHONY_PLUS_RESTART_CWD", Application.get_env(:symphony_plus, :launch_cwd, File.cwd!())}
        ]
      end

    case System.cmd(script, args, cd: policy.installation_root, env: env, stderr_to_stdout: true, parallelism: true) do
      {_output, 0} -> :ok
      {_output, status} -> {:error, {:helper_failed, status}}
    end
  end

  defp revision(nil), do: nil

  defp revision(root) do
    case System.cmd("git", ["rev-parse", "HEAD"], cd: root, stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> nil
    end
  end

  defp fail(state, kind, outcome, reason), do: %{state | status: status(kind, revision(state.policy.installation_root), candidate_revision(state), DateTime.utc_now(), outcome, inspect(reason))}

  defp put_status(state, kind, reason),
    do: %{state | status: status(kind, revision(state.policy.installation_root), candidate_revision(state), state.status.last_checked_at, Atom.to_string(kind), reason)}

  defp candidate_revision(%{candidate: nil}), do: nil
  defp candidate_revision(%{candidate: candidate}), do: candidate.revision
  defp empty_status(kind), do: status(kind, nil, nil, nil, Atom.to_string(kind), nil)

  defp status(kind, running, candidate, checked, outcome, reason) when kind in @states do
    %{state: kind, running_revision: running, candidate_revision: candidate, last_checked_at: checked, last_outcome: String.slice(outcome, 0, 80), reason: sanitize(reason)}
  end

  defp sanitize(nil), do: nil
  defp sanitize(value), do: value |> to_string() |> String.replace(~r/[\r\n\t]+/, " ") |> String.slice(0, 160)
  defp check_outcome({:ok, :current}), do: "current"
  defp check_outcome({:ok, _candidate}), do: "candidate"
  defp check_outcome({:error, _reason}), do: "failed"

  defp schedule(state, delay) do
    if state.timer, do: Process.cancel_timer(state.timer)
    %{state | timer: Process.send_after(self(), :check, delay)}
  end

  defp configured_policy(nil) do
    case Config.settings() do
      {:ok, settings} -> settings.updates
      _ -> %Config.Schema.Updates{}
    end
  end

  defp configured_policy(supervisor) do
    case ProjectRuntimeSupervisor.update_policy(supervisor) do
      {:ok, policy} -> policy
      {:error, _reason} -> %Config.Schema.Updates{}
    end
  end

  defp policy_result(nil), do: {:ok, configured_policy(nil)}
  defp policy_result(supervisor), do: ProjectRuntimeSupervisor.update_policy(supervisor)

  defp begin_runtime_drain(%{runtime_supervisor: nil} = state), do: Orchestrator.begin_update_drain(state.orchestrator)

  defp begin_runtime_drain(state) do
    :persistent_term.put({__MODULE__, :draining, state.runtime_supervisor}, true)
    ProjectRuntimeSupervisor.begin_update_drain(state.runtime_supervisor)
  end

  defp runtime_quiescent?(%{runtime_supervisor: nil} = state),
    do: Orchestrator.update_quiescent?(state.drain_token, state.orchestrator) and MergeQueue.idle?(state.merge_queue)

  defp runtime_quiescent?(state), do: ProjectRuntimeSupervisor.update_quiescent?(state.runtime_supervisor, state.drain_token)

  defp cancel_runtime_drain(%{runtime_supervisor: nil} = state), do: Orchestrator.cancel_update_drain(state.drain_token, state.orchestrator)

  defp cancel_runtime_drain(state) do
    :persistent_term.erase({__MODULE__, :draining, state.runtime_supervisor})
    ProjectRuntimeSupervisor.cancel_update_drain(state.runtime_supervisor, state.drain_token)
  end
end
