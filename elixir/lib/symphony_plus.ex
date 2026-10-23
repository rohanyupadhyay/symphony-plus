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

    children = [
      {Phoenix.PubSub, name: SymphonyPlus.PubSub},
      SymphonyPlus.GitHub.AuthCache,
      SymphonyPlus.WorkflowStore,
      SymphonyPlus.GitHub.MergeQueue,
      SymphonyPlus.AgentRuntimeSupervisor,
      SymphonyPlus.UpdateManager,
      SymphonyPlus.HttpServer,
      SymphonyPlus.StatusDashboard
    ]

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

  defp plain_arguments, do: Enum.map(:init.get_plain_arguments(), &to_string/1)
end
