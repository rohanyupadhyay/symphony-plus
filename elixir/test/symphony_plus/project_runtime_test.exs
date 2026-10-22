defmodule SymphonyPlus.ProjectRuntimeTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.{ProjectRuntime, ProjectRuntimeSupervisor}

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
