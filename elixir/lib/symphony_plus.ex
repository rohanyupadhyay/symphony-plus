defmodule SymphonyPlus do
  @moduledoc """
  Entry point for the Symphony Plus orchestrator.
  """

  @doc """
  Start the agent runtime in the current BEAM node.
  """
  @spec start_link() :: Supervisor.on_start()
  def start_link do
    SymphonyPlus.AgentRuntimeSupervisor.start_link([])
  end
end

defmodule SymphonyPlus.Application do
  @moduledoc """
  OTP application entrypoint that starts core supervisors and workers.
  """

  use Application

  @dialyzer {:nowarn_function, start_burrito_cli: 0}

  @impl true
  def start(_type, _args) do
    if burrito_runtime?() do
      start_burrito_cli()
    else
      start_runtime()
    end
  end

  @doc false
  @spec start_runtime() :: Supervisor.on_start()
  def start_runtime do
    :ok = SymphonyPlus.LogFile.configure()

    configured_workflow = Application.get_env(:symphony_plus, :workflow_file_path)
    workflow_available? = is_binary(configured_workflow) and File.regular?(configured_workflow)

    service_children = [
      {Phoenix.PubSub, name: SymphonyPlus.PubSub},
      {Registry, keys: :unique, name: SymphonyPlus.ProjectQueueRegistry},
      SymphonyPlus.GitHub.AuthCache,
      SymphonyPlus.ProjectRuntimeSupervisor,
      SymphonyPlus.ProjectRegistry,
      {SymphonyPlus.HttpServer, http_server_options()},
      {SymphonyPlus.StatusDashboard, enabled: false, refresh_ms: 1_000, render_interval_ms: 16}
    ]

    legacy_children =
      if workflow_available? do
        [
          SymphonyPlus.GitHub.MergeQueue,
          SymphonyPlus.WorkflowStore,
          SymphonyPlus.AgentRuntimeSupervisor
        ]
      else
        []
      end

    updater =
      if workflow_available?,
        do: SymphonyPlus.UpdateManager,
        else: {SymphonyPlus.UpdateManager, runtime_supervisor: SymphonyPlus.ProjectRuntimeSupervisor}

    children = service_children ++ legacy_children ++ [updater]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: SymphonyPlus.Supervisor
    )
  end

  @impl true
  def stop(_state) do
    SymphonyPlus.StatusDashboard.render_offline_status()
    :ok
  end

  defp start_burrito_cli do
    Task.start_link(fn ->
      SymphonyPlus.CLI.main(
        plain_arguments(),
        &start_runtime/0
      )
    end)
  end

  defp burrito_runtime?, do: System.get_env("__BURRITO") == "1"

  defp http_server_options do
    case Application.get_env(:symphony_plus, :server_port_override) do
      port when is_integer(port) and port >= 0 -> [port: port, host: "127.0.0.1"]
      _ -> [host: "127.0.0.1"]
    end
  end

  defp plain_arguments, do: Enum.map(:init.get_plain_arguments(), &to_string/1)
end
