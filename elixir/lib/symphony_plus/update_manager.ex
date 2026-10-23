defmodule SymphonyPlus.UpdateManager do
  @moduledoc "Owns automatic update scheduling, admission, and activation handoff."

  use GenServer
  require Logger

  alias SymphonyPlus.{Config, Orchestrator, SourceUpdate}
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

  @impl true
  def init(opts) do
    state = %{
      policy: Keyword.get(opts, :policy, Config.update_settings()),
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
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  @impl true
  def handle_cast(:check, %{checking: true} = state), do: {:noreply, state}
  def handle_cast(:check, state), do: {:noreply, run_check(reconcile_policy(state))}

  @impl true
  def handle_info(:check, %{checking: true} = state), do: {:noreply, state}
  def handle_info(:check, state), do: {:noreply, run_check(reconcile_policy(%{state | timer: nil}))}
  def handle_info(:admit, state), do: {:noreply, maybe_admit(state)}

  defp run_check(%{policy: %{enabled: false}} = state), do: %{state | status: empty_status(:disabled)}

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
    {:ok, token} = Orchestrator.begin_update_drain(state.orchestrator)
    Logger.info("update drain outcome=started installation=#{state.policy.installation_root} revision=#{state.candidate.revision}")
    Process.send_after(self(), :admit, 100)
    put_status(%{state | drain_token: token}, :draining, "waiting for admitted work to finish")
  end

  defp maybe_admit(%{drain_token: nil} = state), do: state

  defp maybe_admit(state) do
    if Orchestrator.update_quiescent?(state.drain_token, state.orchestrator) and MergeQueue.idle?(state.merge_queue) do
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
    policy = Config.update_settings()

    if state.policy.enabled and not policy.enabled and state.drain_token,
      do: Orchestrator.cancel_update_drain(state.drain_token, state.orchestrator)

    %{
      state
      | policy: policy,
        drain_token: if(policy.enabled, do: state.drain_token, else: nil),
        candidate: if(policy.enabled, do: state.candidate, else: nil)
    }
  rescue
    _ -> state
  end

  defp abandon(state, reason) do
    if state.drain_token, do: Orchestrator.cancel_update_drain(state.drain_token, state.orchestrator)
    fail(%{state | drain_token: nil, candidate: nil}, :failed, "candidate_abandoned", reason)
  end

  defp activate(policy, candidate, pid) do
    script = Path.join(policy.installation_root, "elixir/scripts/apply-source-update")

    args = [
      policy.installation_root,
      candidate.prepared_path,
      candidate.revision,
      to_string(pid),
      policy.launcher_command
    ]

    case System.cmd(script, args, cd: policy.installation_root, stderr_to_stdout: true, parallelism: true) do
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
  defp schedule(%{policy: %{enabled: false}} = state, _delay), do: state

  defp schedule(state, delay) do
    if state.timer, do: Process.cancel_timer(state.timer)
    %{state | timer: Process.send_after(self(), :check, delay)}
  end
end
