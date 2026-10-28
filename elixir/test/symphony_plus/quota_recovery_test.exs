defmodule SymphonyPlus.QuotaRecoveryTest do
  use SymphonyPlus.TestSupport
  alias SymphonyPlus.QuotaWaitStore

  setup do
    root = Path.dirname(Workflow.workflow_file_path())
    write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory", workspace_root: "workspaces", poll_interval_ms: 60_000)
    Application.put_env(:symphony_plus, :memory_tracker_issues, [issue()])
    %{root: root, workspace_root: Path.join(root, "workspaces")}
  end

  test "workflow-relative waits restore at the same local root", %{workspace_root: root} do
    put_wait(root, %{"worker_host" => nil})
    pid = start_supervised!({Orchestrator, name: nil})
    assert [wait] = Orchestrator.snapshot(pid, 1_000).quota_waiting
    assert wait.workspace_path == Path.join(root, "MT-QUOTA")
  end

  test "restored SSH waits retain their original host", %{workspace_root: root} do
    put_wait(root, %{"worker_host" => "original-worker"})
    pid = start_supervised!({Orchestrator, name: nil})
    assert [wait] = Orchestrator.snapshot(pid, 1_000).quota_waiting
    assert wait.worker_host == "original-worker"
  end

  test "legacy waits cannot guess a local worker after worker configuration changes", %{workspace_root: root} do
    write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory", workspace_root: root)
    put_wait(root, %{})
    pid = start_supervised!({Orchestrator, name: nil})
    assert [wait] = Orchestrator.snapshot(pid, 1_000).blocked
    assert wait.status == :operator_blocked
    assert wait.reason =~ "worker identity"
  end

  test "terminal quota waits clean their preserved workspace and durable record", %{workspace_root: root} do
    put_wait(root, %{"worker_host" => nil})
    issue = issue()
    Application.put_env(:symphony_plus, :memory_tracker_issues, [issue])
    pid = start_supervised!({Orchestrator, name: nil})
    _ = Orchestrator.snapshot(pid, 1_000)
    Application.put_env(:symphony_plus, :memory_tracker_issues, [%{issue | state: "Done"}])
    send(pid, :run_poll_cycle)
    assert Orchestrator.snapshot(pid, 1_000).quota_waiting == []
    refute File.dir?(Path.join(root, "MT-QUOTA"))
    assert :not_found = QuotaWaitStore.fetch(root, "quota-issue")
  end

  test "quota resumes respect tracker-state capacity", %{workspace_root: root} do
    write_workflow_file!(Workflow.workflow_file_path(),
      tracker_kind: "memory",
      workspace_root: root,
      max_concurrent_agents_by_state: %{"In Progress" => 1}
    )

    put_wait(root, %{"worker_host" => nil})
    Application.put_env(:symphony_plus, :memory_tracker_issues, [issue()])
    pid = start_supervised!({Orchestrator, name: nil})
    blocker = %{issue() | id: "blocker", identifier: "MT-BLOCKER"}
    Application.put_env(:symphony_plus, :memory_tracker_issues, [issue(), blocker])
    worker = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(worker, :kill) end)
    entry = running_entry(blocker, worker, nil)

    :sys.replace_state(pid, fn state ->
      %{
        state
        | running: %{"blocker" => entry},
          claimed: MapSet.put(state.claimed, "blocker")
      }
    end)

    :sys.replace_state(pid, fn state ->
      wait = %{state.quota_waits["quota-issue"] | next_recheck_at: ~U[2020-01-01 00:00:00Z]}
      %{state | quota_waits: Map.put(state.quota_waits, "quota-issue", wait)}
    end)

    send(pid, :run_poll_cycle)
    state = :sys.get_state(pid)
    assert state.quota_waits["quota-issue"].status == :waiting
    assert Map.keys(:sys.get_state(pid).running) == ["blocker"]
  end

  test "validated project context updates scheduler limits without replacing retained state" do
    pid = start_supervised!({Orchestrator, name: nil})
    state = :sys.get_state(pid)
    :sys.replace_state(pid, &%{&1 | claimed: MapSet.new(["retained"])})
    settings = Config.settings!()

    settings = %{
      settings
      | polling: %{settings.polling | interval_ms: 12_345},
        agent: %{settings.agent | max_concurrent_agents: 2}
    }

    context = %{
      settings: settings,
      workflow_path: Workflow.workflow_file_path(),
      workflow: %{prompt: "Updated"},
      project_id: "project"
    }

    assert :ok = Orchestrator.update_project_context(pid, context)
    updated = :sys.get_state(pid)
    assert updated.poll_interval_ms == 12_345
    assert updated.max_concurrent_agents == 2
    assert updated.claimed == MapSet.new(["retained"])
    assert updated.task_supervisor == state.task_supervisor
  end

  test "quota resume validates a workflow-relative existing workspace", %{workspace_root: root} do
    File.mkdir_p!(Path.join(root, "MT-QUOTA"))

    assert_raise RuntimeError, ~r/invalid_continuation_reference/, fn ->
      AgentRunner.run(issue(), nil, run_kind: :quota_resume, continuation_reference: :invalid)
    end
  end

  test "remote quota resume refuses a missing preserved workspace before creating it", %{root: root} do
    previous_path = System.get_env("PATH")
    trace = Path.join(root, "ssh-trace")
    File.write!(Path.join(root, "ssh"), "#!/bin/sh\nprintf '%s\\n' \"$*\" >> '#{trace}'\nexit 1\n")
    File.chmod!(Path.join(root, "ssh"), 0o755)
    System.put_env("PATH", root <> ":" <> previous_path)
    on_exit(fn -> System.put_env("PATH", previous_path) end)

    assert_raise RuntimeError, ~r/preserved_workspace_unavailable/, fn ->
      AgentRunner.run(issue(), nil, run_kind: :quota_resume, worker_host: "original-worker")
    end

    assert File.read!(trace) =~ "test -d"
    refute File.read!(trace) =~ "mkdir"
  end

  test "quota resumes keep the original host when that host is at capacity", %{workspace_root: root} do
    write_workflow_file!(Workflow.workflow_file_path(),
      tracker_kind: "memory",
      workspace_root: root,
      worker_ssh_hosts: ["original-worker", "idle-worker"],
      worker_max_concurrent_agents_per_host: 1
    )

    put_wait(root, %{"worker_host" => "original-worker"})
    pid = start_supervised!({Orchestrator, name: nil})
    blocker = %{issue() | id: "blocker", identifier: "MT-BLOCKER"}
    Application.put_env(:symphony_plus, :memory_tracker_issues, [issue(), blocker])
    worker = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(worker, :kill) end)
    entry = running_entry(blocker, worker, "original-worker")

    :sys.replace_state(pid, fn state ->
      wait = %{state.quota_waits["quota-issue"] | next_recheck_at: ~U[2020-01-01 00:00:00Z]}

      %{
        state
        | running: %{"blocker" => entry},
          quota_waits: Map.put(state.quota_waits, "quota-issue", wait),
          claimed: MapSet.put(state.claimed, "blocker")
      }
    end)

    send(pid, :run_poll_cycle)
    state = :sys.get_state(pid)
    assert state.quota_waits["quota-issue"].status == :waiting
    assert Map.keys(state.running) == ["blocker"]
  end

  test "polling a reserved live resume cannot create a second worker and failure frees its slot", %{workspace_root: root} do
    put_wait(root, %{"worker_host" => nil})
    pid = start_supervised!({Orchestrator, name: nil})
    worker = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(worker, :kill) end)
    entry = running_entry(issue(), worker, nil) |> Map.put(:run_kind, :quota_resume)

    :sys.replace_state(pid, fn state ->
      wait = %{state.quota_waits["quota-issue"] | next_recheck_at: ~U[2020-01-01 00:00:00Z], status: :resuming}
      %{state | running: %{"quota-issue" => entry}, quota_waits: Map.put(state.quota_waits, "quota-issue", wait)}
    end)

    send(pid, :run_poll_cycle)
    state = :sys.get_state(pid)
    assert state.running["quota-issue"].pid == worker
    send(pid, {:DOWN, entry.ref, :process, worker, :failed_resume})
    state = :sys.get_state(pid)
    assert state.running == %{}
    assert state.quota_waits["quota-issue"].status == :operator_blocked
    assert state.blocked["quota-issue"].error =~ "failed_resume"
  end

  test "cancelled waits clean up and label-ineligible waits release without starting a resume", %{workspace_root: root} do
    for {state_name, routable, cleanup?} <- [{"Cancelled", true, true}, {"In Progress", false, false}] do
      put_wait(root, %{"worker_host" => nil})
      Application.put_env(:symphony_plus, :memory_tracker_issues, [issue()])
      {:ok, pid} = Orchestrator.start_link(name: nil)

      Application.put_env(:symphony_plus, :memory_tracker_issues, [
        %{issue() | state: state_name, dispatchable: routable}
      ])

      send(pid, :run_poll_cycle)
      state = :sys.get_state(pid)
      assert state.quota_waits == %{}
      assert state.running == %{}
      refute MapSet.member?(state.claimed, "quota-issue")
      assert File.dir?(Path.join(root, "MT-QUOTA")) == not cleanup?
      GenServer.stop(pid)
    end
  end

  defp running_entry(issue, worker, host) do
    %{
      pid: worker,
      ref: Process.monitor(worker),
      issue: issue,
      identifier: issue.identifier,
      worker_host: host,
      started_at: DateTime.utc_now(),
      last_codex_timestamp: DateTime.utc_now()
    }
  end

  test "restart dispatches the saved native thread and clears the reservation after completion", %{root: root, workspace_root: workspace_root} do
    {binary, trace} = fake_codex(root)

    write_workflow_file!(Workflow.workflow_file_path(),
      tracker_kind: "memory",
      workspace_root: "workspaces",
      codex_command: binary,
      max_turns: 1
    )

    put_wait(workspace_root, %{"worker_host" => nil, "status" => "resuming", "next_recheck_at" => "2020-01-01T00:00:00Z"})
    pid = start_supervised!({Orchestrator, name: nil})
    assert_eventually(fn -> Map.has_key?(:sys.get_state(pid).retry_attempts, "quota-issue") end)
    requests = File.read!(trace)
    assert requests =~ "thread/resume"
    assert requests =~ "thread-original"
    refute requests =~ "thread/start"
    state = :sys.get_state(pid)
    assert state.running == %{}
    assert state.quota_waits == %{}
    assert :not_found = QuotaWaitStore.fetch(workspace_root, "quota-issue")
  end

  test "a due native quota resume completes during an installation drain", %{root: root, workspace_root: workspace_root} do
    {binary, trace} = fake_codex(root)

    write_workflow_file!(Workflow.workflow_file_path(),
      tracker_kind: "memory",
      workspace_root: "workspaces",
      codex_command: binary,
      max_turns: 1
    )

    put_wait(workspace_root, %{"worker_host" => nil})
    pid = start_supervised!({Orchestrator, name: nil})
    {:ok, token} = Orchestrator.begin_update_drain(pid)

    :sys.replace_state(pid, fn state ->
      wait = %{state.quota_waits["quota-issue"] | next_recheck_at: ~U[2020-01-01 00:00:00Z]}
      %{state | quota_waits: Map.put(state.quota_waits, "quota-issue", wait)}
    end)

    send(pid, :run_poll_cycle)
    assert_eventually(fn -> :sys.get_state(pid).quota_waits == %{} end)
    Application.put_env(:symphony_plus, :memory_tracker_issues, [%{issue() | state: "Done"}])
    assert_eventually(fn -> Orchestrator.update_quiescent?(token, pid) end, 300)
    assert File.read!(trace) =~ "thread/resume"
    refute File.read!(trace) =~ "thread/start"
    assert :not_found = QuotaWaitStore.fetch(workspace_root, "quota-issue")
  end

  defp fake_codex(root) do
    trace = Path.join(root, "native-requests")
    binary = Path.join(root, "fake-codex")

    File.write!(binary, """
    #!/bin/sh
    count=0
    while IFS= read -r line; do
      printf '%s\n' "$line" >> "#{trace}"
      count=$((count + 1))
      case "$count" in
        1) printf '%s\n' '{"id":1,"result":{}}' ;;
        2) ;;
        3) printf '%s\n' '{"id":4,"result":{"thread":{"id":"thread-original"}}}' ;;
        4)
          printf '%s\n' '{"id":3,"result":{"turn":{"id":"turn-resumed"}}}'
          printf '%s\n' '{"method":"turn/completed","params":{}}'
          ;;
      esac
    done
    """)

    File.chmod!(binary, 0o755)
    {binary, trace}
  end

  defp assert_eventually(fun, attempts \\ 100)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.(),
      do: :ok,
      else:
        (
          Process.sleep(10)
          assert_eventually(fun, attempts - 1)
        )
  end

  defp issue, do: %Issue{id: "quota-issue", identifier: "MT-QUOTA", title: "Resume", state: "In Progress", dispatchable: true}

  defp put_wait(root, overrides) do
    File.mkdir_p!(Path.join(root, "MT-QUOTA"))

    record = %{
      "version" => 1,
      "issue_id" => "quota-issue",
      "issue_identifier" => "MT-QUOTA",
      "harness" => "codex",
      "pool_key" => "codex:default",
      "status" => "waiting",
      "renewal_at" => "2099-01-01T00:00:00Z",
      "next_recheck_at" => "2099-01-01T00:00:00Z",
      "workspace_key" => "MT-QUOTA",
      "continuation" => %{"harness" => "codex", "native_id" => "thread-original", "issue_id" => "quota-issue", "workspace_key" => "MT-QUOTA"},
      "last_outcome" => "quota_exhausted",
      "observed_at" => "2026-01-01T00:00:00Z",
      "updated_at" => "2026-01-01T00:00:00Z"
    }

    assert :ok = QuotaWaitStore.put(root, Map.merge(record, overrides))
  end
end
