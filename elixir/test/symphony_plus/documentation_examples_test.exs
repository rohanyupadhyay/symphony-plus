defmodule SymphonyPlus.DocumentationExamplesTest do
  use ExUnit.Case, async: false
  alias SymphonyPlus.DocumentationSupport, as: Docs
  @moduletag :documentation
  @readme Path.expand("../../README.md", __DIR__)

  test "every marked canonical scenario is registered in this fixed scenario suite" do
    markers = Regex.scan(~r/<!-- docs:scenario ([a-z-]+) -->/, File.read!(@readme), capture: :all_but_first) |> List.flatten()
    assert Enum.sort(markers) == ~w(cold-source-install project-add project-list project-remove release-service-start service-start)
  end

  test "published commands select the target, persist across restart, list offline, and remove without deleting files" do
    Docs.with_fixture(fn f ->
      f = workflow(f)
      ready_file = Path.join(f.root, "update-ready")
      f = Docs.put_env(f, "SYMPHONY_PLUS_UPDATE_READY_FILE", ready_file)

      Docs.with_service(command("service-start"), f, &healthy?/1, fn f ->
        assert eventually(fn -> File.exists?(ready_file) end)
        ready_pid = ready_file |> File.read!() |> String.trim()
        assert {_, 0} = System.cmd("kill", ["-0", ready_pid], stderr_to_stdout: true)
        assert state(f)["projects"] == []
        {out, 0} = Docs.run(command("project-add"), f)
        registration = Jason.decode!(out)["project"]
        assert registration["workflow_path"] == f.env["SYMPHONY_PLUS_WORKFLOW"]
        assert eventually(fn -> Enum.any?(state(f)["projects"], &(&1["state"] == "active")) end)
        {out, 0} = Docs.run(command("project-list"), f)
        assert out =~ registration["id"]
      end)

      refute healthy?(f)
      {out, 0} = Docs.run(command("project-list"), %{f | cwd: f.root})
      assert out =~ f.env["SYMPHONY_PLUS_WORKFLOW"]

      Docs.with_service(command("service-start"), f, &healthy?/1, fn f ->
        assert eventually(fn -> length(state(f)["projects"]) == 1 end)
        [project] = state(f)["projects"]
        marker = Path.join(f.root, "workspaces/keep.txt")
        File.write!(marker, "preserve")
        f = Docs.put_env(f, "SYMPHONY_PLUS_PROJECT_ID", project["id"])
        assert {_out, 0} = Docs.run(command("project-remove"), f)
        assert File.read!(marker) == "preserve"
        assert state(f)["projects"] == []
      end)
    end)
  end

  test "update restarts retain the original cwd for implicit and relative registry log and workflow paths" do
    for explicit_paths? <- [false, true] do
      Docs.with_fixture(fn f ->
        f = workflow(f)
        original_cwd = f.cwd
        launcher_cwd = Path.join(f.root, "installation/elixir")
        File.mkdir_p!(launcher_cwd)
        args = ["--i-understand-that-this-will-be-running-without-the-usual-guardrails", "--port", to_string(f.port)]
        args = if explicit_paths?, do: args ++ ["--data-root", "../data", "--logs-root", "../logs"], else: args
        args = args ++ ["../target-WORKFLOW.md"]
        root = if explicit_paths?, do: f.env["SYMPHONY_PLUS_DATA_ROOT"], else: Path.join(original_cwd, "tmp/symphony-plus")
        logs = if explicit_paths?, do: f.env["SYMPHONY_PLUS_LOGS_ROOT"], else: original_cwd

        f =
          f
          |> Docs.put_env("SYMPHONY_PLUS_RESTART_ARGUMENTS", Jason.encode!(args))
          |> Docs.put_env("SYMPHONY_PLUS_RESTART_CWD", original_cwd)

        Docs.with_service(~s("$SYMPHONY_PLUS_BIN"), %{f | cwd: launcher_cwd}, &healthy?/1, fn f ->
          assert eventually(fn -> length(state(f)["projects"]) == 1 end)
          [project] = state(f)["projects"]
          assert project["workflow_path"] == f.env["SYMPHONY_PLUS_WORKFLOW"]
          assert File.exists?(Path.join(root, "projects.json"))
          assert File.dir?(Path.join(logs, "log"))
          refute File.dir?(Path.join(launcher_cwd, "log"))
          refute File.exists?(Path.join(launcher_cwd, "tmp/symphony-plus/projects.json"))
        end)
      end)
    end
  end

  test "no acknowledgement fails through the actual executable" do
    Docs.with_fixture(fn f ->
      {out, status} = Docs.run(~s("$SYMPHONY_PLUS_BIN" --port "$SYMPHONY_PLUS_PORT"), f)
      assert status == 1
      assert out =~ "--i-understand-that-this-will-be-running-without-the-usual-guardrails"
    end)
  end

  test "separate ports and absolute data roots keep two installations isolated" do
    Docs.with_fixture(fn a ->
      Docs.with_fixture(fn b ->
        a = workflow(a)

        Docs.with_service(command("service-start"), a, &healthy?/1, fn a ->
          Docs.with_service(command("service-start"), b, &healthy?/1, fn b ->
            assert {_out, 0} = Docs.run(command("project-add"), a)
            assert eventually(fn -> length(state(a)["projects"]) == 1 end)
            assert state(b)["projects"] == []
            assert {"No projects registered.\n", 0} = Docs.run(command("project-list"), b)
          end)
        end)
      end)
    end)
  end

  test "a temporarily missing registration recovers after the workflow is repaired" do
    Docs.with_fixture(fn f ->
      f = workflow(f)

      Docs.with_service(command("service-start"), f, &healthy?/1, fn f ->
        assert {_out, 0} = Docs.run(command("project-add"), f)
      end)

      contents = File.read!(f.env["SYMPHONY_PLUS_WORKFLOW"])
      File.rm!(f.env["SYMPHONY_PLUS_WORKFLOW"])

      Docs.with_service(command("service-start"), f, &healthy?/1, fn f ->
        assert eventually(fn -> Enum.any?(state(f)["projects"], &(&1["state"] == "unavailable")) end)
        File.write!(f.env["SYMPHONY_PLUS_WORKFLOW"], contents)
        assert eventually(fn -> Enum.any?(state(f)["projects"], &(&1["state"] == "active")) end)
      end)
    end)
  end

  test "wrong target and service addressing mutations fail observable contract assertions" do
    Docs.with_fixture(fn f ->
      f = workflow(f)

      Docs.with_service(command("service-start"), f, &healthy?/1, fn f ->
        wrong = Docs.put_env(f, "SYMPHONY_PLUS_WORKFLOW", Path.join(f.root, "wrong.md"))
        assert {_out, 1} = Docs.run(command("project-add"), wrong)
        wrong = Docs.put_env(f, "SYMPHONY_PLUS_SERVICE_URL", "http://127.0.0.1:1")
        assert {_out, 1} = Docs.run(command("project-add"), wrong)
        assert state(f)["projects"] == []
      end)
    end)
  end

  defp command(id), do: Docs.command_block!(@readme, id)

  defp workflow(f) do
    path = Path.join(f.root, "target-WORKFLOW.md")
    File.write!(path, "---\ntracker:\n  kind: memory\nworkspace:\n  root: #{Path.join(f.root, "workspaces")}\npolling:\n  interval_ms: 100\n---\nFixture: no issues or hooks.\n")
    Docs.put_env(f, "SYMPHONY_PLUS_WORKFLOW", path)
  end

  defp healthy?(f) do
    case Req.get(f.env["SYMPHONY_PLUS_SERVICE_URL"] <> "/api/v1/state", retry: false, receive_timeout: 500, connect_options: [timeout: 500]) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  defp state(f) do
    Req.get!(f.env["SYMPHONY_PLUS_SERVICE_URL"] <> "/api/v1/state", retry: false).body
  end

  defp eventually(fun, remaining \\ 100)
  defp eventually(_fun, 0), do: false

  defp eventually(fun, remaining) do
    if fun.(),
      do: true,
      else:
        (
          Process.sleep(50)
          eventually(fun, remaining - 1)
        )
  end
end
