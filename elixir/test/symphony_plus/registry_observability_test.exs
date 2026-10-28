defmodule SymphonyPlus.RegistryObservabilityTest do
  use SymphonyPlus.TestSupport
  import Phoenix.ConnTest
  alias SymphonyPlus.{ProjectRuntime, ProjectRuntimeSupervisor}
  @endpoint SymphonyPlusWeb.Endpoint

  setup do
    write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory", workspace_root: "workspaces")
    previous = Application.get_env(:symphony_plus, @endpoint)
    config = Keyword.merge(previous || [], server: false, secret_key_base: String.duplicate("s", 64), orchestrator: Orchestrator)
    Application.put_env(:symphony_plus, @endpoint, config)
    start_supervised!({@endpoint, []})
    on_exit(fn -> Application.put_env(:symphony_plus, @endpoint, previous) end)
    :ok
  end

  test "refresh endpoint addresses every registered scheduler and reports unavailable projects" do
    project_id = "refresh-#{System.unique_integer([:positive])}"
    unavailable_id = project_id <> "-unavailable"

    {:ok, runtime} =
      ProjectRuntimeSupervisor.start_project(%{id: project_id, workflow_path: Workflow.workflow_file_path()})

    {:ok, _} =
      ProjectRuntimeSupervisor.start_project(%{
        id: unavailable_id,
        workflow_path: Workflow.workflow_file_path() <> ".missing"
      })

    on_exit(fn ->
      ProjectRuntimeSupervisor.stop_project(project_id)
      ProjectRuntimeSupervisor.stop_project(unavailable_id)
    end)

    assert %{orchestrator: pid} = ProjectRuntime.snapshot(runtime)
    assert is_pid(pid)
    response = post(build_conn(), "/api/v1/refresh") |> json_response(202)
    assert %{"project_id" => ^project_id, "queued" => true} = Enum.find(response["projects"], &(&1["project_id"] == project_id))
    assert %{"project_id" => ^unavailable_id, "queued" => false, "reason" => "unavailable"} = Enum.find(response["projects"], &(&1["project_id"] == unavailable_id))
  end

  test "project identities survive quota projection and ambiguous issue detail requires project selection" do
    issue = %Issue{id: "GH-1", identifier: "GH-1", title: "Shared identity", state: "In Progress", dispatchable: true}
    Application.put_env(:symphony_plus, :memory_tracker_issues, [issue])
    ids = for suffix <- ["alpha", "beta"], do: "identity-#{System.unique_integer([:positive])}-#{suffix}"

    for project_id <- ids do
      {:ok, runtime} =
        ProjectRuntimeSupervisor.start_project(%{id: project_id, workflow_path: Workflow.workflow_file_path()})

      on_exit(fn -> ProjectRuntimeSupervisor.stop_project(project_id) end)
      pid = ProjectRuntime.snapshot(runtime).orchestrator

      :sys.replace_state(pid, fn state ->
        %{
          state
          | blocked: %{
              "GH-1" => %{
                issue_id: "GH-1",
                identifier: "GH-1",
                issue: issue,
                error: project_id,
                blocked_at: DateTime.utc_now()
              }
            },
            claimed: MapSet.new(["GH-1"])
        }
      end)
    end

    payload = get(build_conn(), "/api/v1/state") |> json_response(200)
    assert Enum.sort(Enum.map(payload["blocked"], & &1["project_id"])) == Enum.sort(ids)
    assert %{"error" => %{"code" => "ambiguous_issue"}} = get(build_conn(), "/api/v1/GH-1") |> json_response(409)
    [project_id | _] = ids
    detail = get(build_conn(), "/api/v1/GH-1?project_id=#{project_id}") |> json_response(200)
    assert detail["project_id"] == project_id
    assert detail["blocked"]["error"] == project_id
  end
end
