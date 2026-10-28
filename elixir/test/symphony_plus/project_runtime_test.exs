defmodule SymphonyPlus.ProjectRuntimeTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.GitHub.MergeQueue
  alias SymphonyPlus.ProjectRuntime
  alias SymphonyPlus.ProjectRuntimeSupervisor

  test "installation and reconfiguration drains have independent ownership" do
    {_root, _workflow, runtime} = runtime_fixture("drain-owners")
    orchestrator = ProjectRuntime.snapshot(runtime).orchestrator
    {:ok, installation} = SymphonyPlus.Orchestrator.begin_update_drain(orchestrator)
    {:ok, reconfiguration} = SymphonyPlus.Orchestrator.begin_reconfiguration_drain(orchestrator)
    refute installation == reconfiguration
    assert :ok = SymphonyPlus.Orchestrator.cancel_update_drain(installation, orchestrator)
    assert :sys.get_state(orchestrator).update_drain_token != nil
    assert SymphonyPlus.Orchestrator.update_quiescent?(reconfiguration, orchestrator)
  end

  test "invalid reload keeps the last good runtime and recovers without replacing it" do
    {root, workflow, runtime} = runtime_fixture("reload-invalid")
    original = ProjectRuntime.snapshot(runtime)
    File.write!(workflow, "---\ntracker: [\n---\n")
    send(runtime, :validate)

    assert %{state: :active, orchestrator: orchestrator, reason: reason} = ProjectRuntime.snapshot(runtime)
    assert orchestrator == original.orchestrator
    assert Process.alive?(orchestrator)
    assert is_binary(reason)

    write_runtime_workflow(workflow, root, 45_000)
    send(runtime, :validate)
    assert %{state: :active, reason: nil, orchestrator: ^orchestrator} = ProjectRuntime.snapshot(runtime)
    assert :sys.get_state(orchestrator).poll_interval_ms == 45_000
  end

  test "valid prompt and policy reload retain the live orchestrator and queue" do
    {root, workflow, runtime} = runtime_fixture("reload-valid")
    original = ProjectRuntime.snapshot(runtime)
    write_runtime_workflow(workflow, root, 30_000)
    send(runtime, :validate)
    current = ProjectRuntime.snapshot(runtime)

    assert current.orchestrator == original.orchestrator
    assert current.merge_queue == original.merge_queue
    assert :sys.get_state(current.orchestrator).poll_interval_ms == 30_000
  end

  test "restoring the original workflow cancels only its reconfiguration drain" do
    {root, workflow, runtime} = runtime_fixture("reload-restored")
    original = File.read!(workflow)
    mtime = File.stat!(workflow).mtime
    orchestrator = ProjectRuntime.snapshot(runtime).orchestrator
    {:ok, installation} = SymphonyPlus.Orchestrator.begin_update_drain(orchestrator)
    :sys.replace_state(orchestrator, &%{&1 | claimed: MapSet.put(&1.claimed, "retained")})

    File.write!(workflow, String.replace(original, Path.join(root, "workspaces"), Path.join(root, "other-workspaces")))
    send(runtime, :validate)
    assert_eventually(fn -> :sys.get_state(runtime).reload_drain != nil end)

    File.write!(workflow, original)
    File.touch!(workflow, mtime)
    send(runtime, :validate)
    assert_eventually(fn -> :sys.get_state(runtime).reload_drain == nil end)
    assert ProjectRuntime.snapshot(runtime).orchestrator == orchestrator
    assert :sys.get_state(orchestrator).update_drain_tokens == %{installation: installation}
  end

  test "invalid workflow during a routing drain restores dispatch for the last good runtime" do
    {root, workflow, runtime} = runtime_fixture("reload-invalid-drain")
    original = File.read!(workflow)
    orchestrator = ProjectRuntime.snapshot(runtime).orchestrator
    :sys.replace_state(orchestrator, &%{&1 | claimed: MapSet.put(&1.claimed, "retained")})

    File.write!(workflow, String.replace(original, Path.join(root, "workspaces"), Path.join(root, "other-workspaces")))
    send(runtime, :validate)
    assert_eventually(fn -> :sys.get_state(runtime).reload_drain != nil end)

    File.write!(workflow, "---\ntracker: [\n---\n")
    send(runtime, :validate)
    assert_eventually(fn -> :sys.get_state(runtime).reload_drain == nil end)
    assert ProjectRuntime.snapshot(runtime).orchestrator == orchestrator
    assert :sys.get_state(orchestrator).update_drain_tokens == %{}
  end

  for phase <- [:begin, :quiescence, :cancel] do
    @tag phase: phase
    test "a busy orchestrator preserves routing reload during #{phase}", %{phase: phase} do
      {root, workflow, runtime} = runtime_fixture("reload-busy-#{phase}")
      original = File.read!(workflow)
      %{orchestrator: orchestrator, merge_queue: queue} = ProjectRuntime.snapshot(runtime)
      {:ok, installation} = SymphonyPlus.Orchestrator.begin_update_drain(orchestrator)
      :sys.replace_state(orchestrator, &%{&1 | claimed: MapSet.put(&1.claimed, "retained")})
      changed = String.replace(original, Path.join(root, "workspaces"), Path.join(root, "other-workspaces"))

      if phase != :begin do
        File.write!(workflow, changed)
        send(runtime, :validate)
        assert_eventually(fn -> :sys.get_state(runtime).reload_drain != nil end)
        assert SymphonyPlus.Orchestrator.snapshot(orchestrator, 1_000).counts.running == 0
      end

      :ok = :sys.suspend(orchestrator)
      on_exit(fn -> if Process.alive?(orchestrator), do: :sys.resume(orchestrator) end)
      File.write!(workflow, if(phase == :cancel, do: original, else: changed))
      send(runtime, :validate)
      Process.sleep(5_500)

      assert %{state: :active, orchestrator: ^orchestrator, merge_queue: ^queue} = ProjectRuntime.snapshot(runtime)
      assert ProjectRuntime.configuration(runtime).workspace.root == Path.join(root, "workspaces")
      assert MergeQueue.idle?(queue)
      :ok = :sys.resume(orchestrator)

      if phase == :cancel do
        assert_eventually(fn -> :sys.get_state(runtime).reload_drain == nil end, 2_500)
        assert :sys.get_state(orchestrator).update_drain_tokens == %{installation: installation}
        assert ProjectRuntime.snapshot(runtime).orchestrator == orchestrator
      else
        assert_eventually(fn -> :sys.get_state(runtime).reload_drain != nil end, 2_500)
        assert ProjectRuntime.snapshot(runtime).orchestrator == orchestrator
        assert :sys.get_state(orchestrator).claimed == MapSet.new(["retained"])
        assert map_size(:sys.get_state(orchestrator).update_drain_tokens) == 2
        :sys.replace_state(orchestrator, &%{&1 | claimed: MapSet.new()})

        assert_eventually(fn -> ProjectRuntime.snapshot(runtime).orchestrator != orchestrator end, 2_500)
        replacement = ProjectRuntime.snapshot(runtime).orchestrator
        assert SymphonyPlus.Orchestrator.snapshot(replacement, 1_000).counts.running == 0
        assert ProjectRuntime.configuration(runtime).workspace.root == Path.join(root, "other-workspaces")
      end
    end
  end

  for rollback <- [:restored, :invalid] do
    @tag rollback: rollback
    test "a pending routing drain is cancelled after #{rollback} workflow", %{rollback: rollback} do
      {root, workflow, runtime} = runtime_fixture("reload-pending-#{rollback}")
      original = File.read!(workflow)
      mtime = File.stat!(workflow).mtime
      orchestrator = ProjectRuntime.snapshot(runtime).orchestrator
      {:ok, installation} = SymphonyPlus.Orchestrator.begin_update_drain(orchestrator)
      :ok = :sys.suspend(orchestrator)
      on_exit(fn -> if Process.alive?(orchestrator), do: :sys.resume(orchestrator) end)

      File.write!(workflow, String.replace(original, Path.join(root, "workspaces"), Path.join(root, "other-workspaces")))
      send(runtime, :validate)
      assert %{orchestrator: ^orchestrator, reason: reason} = GenServer.call(runtime, :snapshot, 1_000)
      assert is_binary(reason)

      File.write!(workflow, if(rollback == :restored, do: original, else: "---\ntracker: [\n---\n"))
      File.touch!(workflow, mtime)
      send(runtime, :validate)
      assert %{orchestrator: ^orchestrator} = GenServer.call(runtime, :snapshot, 1_000)
      assert ProjectRuntime.configuration(runtime).workspace.root == Path.join(root, "workspaces")
      :ok = :sys.resume(orchestrator)

      assert_eventually(fn ->
        state = :sys.get_state(runtime)
        state.reload_request == nil and state.reload_drain == nil
      end)

      assert :sys.get_state(orchestrator).update_drain_tokens == %{installation: installation}
      assert SymphonyPlus.Orchestrator.snapshot(orchestrator, 1_000).counts.running == 0
      assert ProjectRuntime.snapshot(runtime).orchestrator == orchestrator
    end
  end

  test "an orchestrator exit during a pending routing drain recovers the project" do
    {root, workflow, runtime} = runtime_fixture("reload-pending-exit")
    orchestrator = ProjectRuntime.snapshot(runtime).orchestrator
    :ok = :sys.suspend(orchestrator)
    on_exit(fn -> if Process.alive?(orchestrator), do: :sys.resume(orchestrator) end)

    original = File.read!(workflow)
    File.write!(workflow, String.replace(original, Path.join(root, "workspaces"), Path.join(root, "other-workspaces")))
    send(runtime, :validate)
    assert %{orchestrator: ^orchestrator} = GenServer.call(runtime, :snapshot, 1_000)
    Process.exit(orchestrator, :kill)

    assert_eventually(
      fn ->
        snapshot = ProjectRuntime.snapshot(runtime)
        snapshot.state == :active and is_pid(snapshot.orchestrator) and snapshot.orchestrator != orchestrator
      end,
      2_500
    )

    replacement = ProjectRuntime.snapshot(runtime).orchestrator
    assert SymphonyPlus.Orchestrator.snapshot(replacement, 1_000).counts.running == 0
    assert ProjectRuntime.configuration(runtime).workspace.root == Path.join(root, "other-workspaces")
    assert :sys.get_state(runtime).reload_request == nil
  end

  test "a busy merge queue cannot crash the project runtime during prompt reload" do
    {root, workflow, runtime} = runtime_fixture("reload-busy-queue")
    %{orchestrator: orchestrator, merge_queue: queue} = ProjectRuntime.snapshot(runtime)
    :ok = :sys.suspend(queue)
    on_exit(fn -> if Process.alive?(queue), do: :sys.resume(queue) end)

    write_runtime_workflow(workflow, root, 30_000)
    send(runtime, :validate)
    Process.sleep(5_500)
    assert Process.alive?(runtime)
    assert Process.alive?(orchestrator)
    assert Process.alive?(queue)
    assert ProjectRuntime.snapshot(runtime).orchestrator == orchestrator
  end

  test "registered projects own a queue with their repository policy" do
    {_root, _workflow, runtime} = runtime_fixture("queue-owner")
    assert %{merge_queue: queue} = ProjectRuntime.snapshot(runtime)
    assert is_pid(queue)
    assert %{enabled: false, queues: queues} = MergeQueue.status(queue)
    assert queues == %{}
    assert MergeQueue.idle?(queue)
  end

  test "invalid registrations remain unavailable and activate after repair" do
    root = Path.join(System.tmp_dir!(), "runtime-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    workflow = Path.join(root, "WORKFLOW.md")
    {:ok, pid} = start_supervised({ProjectRuntime, registration: %{id: "project", workflow_path: workflow}})

    assert_eventually(fn -> ProjectRuntime.snapshot(pid).state == :unavailable end)
    File.write!(workflow, "---\ntracker:\n  kind: memory\nworkspace:\n  root: tmp/workspaces\n---\nPrompt\n")
    assert_eventually(fn -> ProjectRuntime.snapshot(pid).state == :active end, 2_500)
    File.rm_rf(root)
  end

  test "two valid registrations own distinct live orchestrators" do
    root = Path.join(System.tmp_dir!(), "runtime-pair-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    runtimes =
      for id <- ["alpha", "beta"] do
        project_root = Path.join(root, id)
        File.mkdir_p!(project_root)
        workflow = Path.join(project_root, "WORKFLOW.md")

        File.write!(
          workflow,
          "---\ntracker:\n  kind: memory\npolling:\n  interval_ms: 60000\nworkspace:\n  root: #{Path.join(project_root, "workspaces")}\n---\nPrompt for #{id}\n"
        )

        start_supervised!(
          Supervisor.child_spec(
            {ProjectRuntime, registration: %{id: id, workflow_path: workflow}},
            id: {ProjectRuntime, id}
          )
        )
      end

    assert_eventually(fn ->
      snapshots = Enum.map(runtimes, &ProjectRuntime.snapshot/1)

      Enum.all?(snapshots, fn snapshot ->
        snapshot.state == :active and is_pid(snapshot.orchestrator) and Process.alive?(snapshot.orchestrator)
      end) and
        snapshots |> Enum.map(& &1.orchestrator) |> Enum.uniq() |> length() == 2
    end)

    File.rm_rf(root)
  end

  test "supervisor aggregate attributes every project snapshot" do
    root = Path.join(System.tmp_dir!(), "runtime-aggregate-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    workflow = Path.join(root, "WORKFLOW.md")

    File.write!(
      workflow,
      "---\ntracker:\n  kind: memory\npolling:\n  interval_ms: 60000\nworkspace:\n  root: #{Path.join(root, "workspaces")}\n---\nPrompt\n"
    )

    supervisor = start_supervised!({ProjectRuntimeSupervisor, name: nil})
    registration = %{id: "alpha", workflow_path: workflow}
    assert {:ok, _runtime} = ProjectRuntimeSupervisor.start_project(registration, supervisor: supervisor)

    assert_eventually(fn ->
      snapshot = ProjectRuntimeSupervisor.aggregate_snapshot(supervisor)

      snapshot.projects == [%{id: "alpha", workflow_path: workflow, state: :active, failure_reason: nil}] and
        snapshot.counts == %{running: 0, retrying: 0, blocked: 0, quota_waiting: 0}
    end)

    File.rm_rf(root)
  end

  defp assert_eventually(fun, timeout \\ 1_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    eventually(fun, deadline)
  end

  defp runtime_fixture(id) do
    root = Path.join(System.tmp_dir!(), "#{id}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    workflow = Path.join(root, "WORKFLOW.md")
    write_runtime_workflow(workflow, root, 60_000)
    on_exit(fn -> File.rm_rf(root) end)
    runtime = start_supervised!({ProjectRuntime, registration: %{id: id, workflow_path: workflow}})
    assert_eventually(fn -> ProjectRuntime.snapshot(runtime).state == :active end)
    {root, workflow, runtime}
  end

  defp write_runtime_workflow(path, root, interval) do
    File.write!(path, "---\ntracker:\n  kind: memory\npolling:\n  interval_ms: #{interval}\nworkspace:\n  root: #{Path.join(root, "workspaces")}\n---\nPrompt #{interval}\n")
  end

  defp eventually(fun, deadline) do
    if fun.() do
      assert true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("condition did not become true")
      else
        Process.sleep(20)
        eventually(fun, deadline)
      end
    end
  end
end
