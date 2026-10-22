defmodule SymphonyPlus.ProjectRuntimeTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.ProjectRuntime

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
