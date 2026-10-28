defmodule SymphonyPlus.UpdateManagerTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.Config.Schema.Updates
  alias SymphonyPlus.GitHub.MergeQueue
  alias SymphonyPlus.ProjectRuntime
  alias SymphonyPlus.ProjectRuntimeSupervisor
  alias SymphonyPlus.UpdateManager

  test "registry updater drains every project and defers new activations" do
    root = Path.join(System.tmp_dir!(), "registry-update-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "installation/.git"))
    on_exit(fn -> File.rm_rf(root) end)
    supervisor = start_supervised!({ProjectRuntimeSupervisor, name: nil})

    for id <- ["policy", "other"] do
      path = Path.join(root, "#{id}.md")

      updates =
        if id == "policy" do
          """
          updates:
            enabled: true
            interval_ms: 60000
            installation_root: #{root}/installation
            prepare_command: "true"
            launcher_command: "true"
          """
        else
          ""
        end

      File.write!(path, """
      ---
      tracker:
        kind: memory
      polling:
        interval_ms: 60000
      workspace:
        root: #{root}/#{id}-workspaces
      #{updates}---
      Prompt
      """)

      assert {:ok, _} = ProjectRuntimeSupervisor.start_project(%{id: id, workflow_path: path}, supervisor: supervisor)
    end

    eventually(fn -> Enum.all?(ProjectRuntimeSupervisor.snapshots(supervisor), &(&1.state == :active)) end)
    [other, _policy] = ProjectRuntimeSupervisor.snapshots(supervisor)
    :sys.replace_state(other.orchestrator, &%{&1 | claimed: MapSet.new(["retained"])})
    owner = self()

    manager =
      start_supervised!(
        {UpdateManager,
         name: nil,
         runtime_supervisor: supervisor,
         source: __MODULE__.CandidateSource,
         activator: fn _, _, _ ->
           send(owner, :registry_activated)
           :ok
         end,
         stopper: fn -> :ok end}
      )

    eventually(fn -> UpdateManager.status(manager).state == :draining end)
    refute_receive :registry_activated, 150
    assert UpdateManager.draining?(supervisor)

    path = Path.join(root, "late.md")

    File.write!(path, """
    ---
    tracker:
      kind: memory
    workspace:
      root: #{root}/late-workspaces
    ---
    Prompt
    """)

    assert {:ok, late} = ProjectRuntimeSupervisor.start_project(%{id: "late", workflow_path: path}, supervisor: supervisor)
    eventually(fn -> ProjectRuntime.snapshot(late).state == :unavailable end)
    assert ProjectRuntime.snapshot(late).orchestrator == nil
    :sys.replace_state(other.orchestrator, &%{&1 | claimed: MapSet.new()})
    assert_receive :registry_activated, 1_000
  end

  test "disabled registry updater reports conflicting installation policies as blocked" do
    root = Path.join(System.tmp_dir!(), "policy-conflict-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "installation/.git"))
    on_exit(fn -> File.rm_rf(root) end)
    supervisor = start_supervised!({ProjectRuntimeSupervisor, name: nil})

    for id <- ["a", "b"] do
      path = Path.join(root, "#{id}.md")

      File.write!(
        path,
        """
        ---
        tracker:
          kind: memory
        workspace:
          root: #{root}/#{id}-workspaces
        updates:
          enabled: true
          installation_root: #{root}/installation
          prepare_command: "true"
          launcher_command: "#{id}"
        ---
        Prompt
        """
      )

      assert {:ok, _} = ProjectRuntimeSupervisor.start_project(%{id: id, workflow_path: path}, supervisor: supervisor)
    end

    eventually(fn -> Enum.all?(ProjectRuntimeSupervisor.snapshots(supervisor), &(&1.state == :active)) end)
    assert {:error, :conflicting_update_policies} = ProjectRuntimeSupervisor.update_policy(supervisor)
    options = [name: nil, runtime_supervisor: supervisor, source: __MODULE__.CurrentSource]
    manager = start_supervised!({UpdateManager, options})
    eventually(fn -> UpdateManager.status(manager).state == :blocked end)
  end

  defmodule CurrentSource do
    def discover(_root, _remote), do: {:ok, :current}
    def prepare(_root, _candidate, _command), do: {:error, :unexpected_prepare}
    def candidate_still_current?(_root, _remote, _candidate), do: true
  end

  defmodule CandidateSource do
    @revision String.duplicate("a", 40)
    def discover(_root, _remote), do: {:ok, %{revision: @revision, default_branch: "main", detected_at: DateTime.utc_now()}}
    def prepare(_root, _candidate, _command), do: {:ok, "/prepared"}
    def candidate_still_current?(_root, _remote, _candidate), do: true
  end

  defmodule IdleGate do
    use GenServer
    def start_link(opts), do: GenServer.start_link(__MODULE__, %{}, opts)
    def init(state), do: {:ok, state}
    def handle_call(:begin_update_drain, _from, state), do: {:reply, {:ok, :drain}, state}
    def handle_call({:update_quiescent?, :drain}, _from, state), do: {:reply, true, state}
    def handle_call(:idle?, _from, state), do: {:reply, true, state}
  end

  test "is inert while disabled" do
    policy = %Updates{enabled: false, interval_ms: 10}
    pid = start_supervised!({UpdateManager, name: nil, policy: policy, source: CurrentSource})
    assert %{state: :disabled, candidate_revision: nil} = UpdateManager.status(pid)
  end

  test "non-overlapping checks settle on current" do
    policy = %Updates{
      enabled: true,
      interval_ms: 60_000,
      installation_root: System.tmp_dir!(),
      remote: "origin",
      prepare_command: "true",
      launcher_command: "true"
    }

    pid = start_supervised!({UpdateManager, name: nil, policy: policy, source: CurrentSource})
    UpdateManager.check_now(pid)
    UpdateManager.check_now(pid)
    eventually(fn -> UpdateManager.status(pid).state == :current end)
  end

  test "merge queue reports idle synchronously" do
    pid = start_supervised!({MergeQueue, name: nil, enabled: false, initial_delay: 60_000})
    assert MergeQueue.idle?(pid)
    :sys.replace_state(pid, &%{&1 | queues: %{{"owner/repo", "main"} => [:entry]}})
    refute MergeQueue.idle?(pid)
  end

  test "successful handoff records activation and requests controlled stop" do
    gate = start_supervised!({IdleGate, name: nil})
    owner = self()
    policy = enabled_policy()

    pid =
      start_supervised!(
        {UpdateManager,
         name: nil,
         policy: policy,
         source: CandidateSource,
         orchestrator: gate,
         merge_queue: gate,
         activator: fn _policy, candidate, _pid ->
           send(owner, {:activated, candidate.revision})
           :ok
         end,
         stopper: fn -> send(owner, :stop_requested) end}
      )

    assert_receive {:activated, revision}, 1_000
    assert revision == String.duplicate("a", 40)
    assert_receive :stop_requested
    assert %{state: :activating, last_outcome: "activating"} = UpdateManager.status(pid)
  end

  test "failed activation is bounded and does not stop" do
    gate = start_supervised!({IdleGate, name: nil})
    owner = self()
    policy = enabled_policy()

    pid =
      start_supervised!(
        {UpdateManager,
         name: nil,
         policy: policy,
         source: CandidateSource,
         orchestrator: gate,
         merge_queue: gate,
         activator: fn _, _, _ -> {:error, :launcher_failed} end,
         stopper: fn -> send(owner, :unexpected_stop) end}
      )

    eventually(fn -> UpdateManager.status(pid).state == :blocked end)
    refute_receive :unexpected_stop
    assert UpdateManager.status(pid).reason =~ "launcher_failed"
  end

  defp enabled_policy do
    %Updates{
      enabled: true,
      interval_ms: 60_000,
      installation_root: System.tmp_dir!(),
      remote: "origin",
      prepare_command: "true",
      launcher_command: "true"
    }
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(fun, attempts) when attempts > 0 do
    if fun.(),
      do: :ok,
      else:
        (
          Process.sleep(10)
          eventually(fun, attempts - 1)
        )
  end

  defp eventually(_fun, 0), do: flunk("condition did not become true")
end
