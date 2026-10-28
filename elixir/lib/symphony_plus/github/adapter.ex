defmodule SymphonyPlus.GitHub.Adapter do
  @moduledoc """
  GitHub Issues-backed tracker adapter.
  """

  @behaviour SymphonyPlus.Tracker

  alias SymphonyPlus.GitHub.{AgentTool, Client, GitPush, WorkflowControl}
  alias SymphonyPlus.Tracker.Issue

  @active_states ["open"]
  @terminal_states ["closed"]

  @spec validate_config(map()) :: :ok | {:error, term()}
  def validate_config(tracker_settings) do
    with :ok <-
           validate_states(
             tracker_settings.active_states,
             @active_states,
             :missing_github_active_states
           ),
         :ok <-
           validate_states(
             tracker_settings.terminal_states,
             @terminal_states,
             :missing_github_terminal_states
           ),
         :ok <- WorkflowControl.validate_settings(tracker_settings.provider),
         :ok <- validate_bootstrap(tracker_settings.provider) do
      Client.validate_settings(tracker_settings)
    end
  end

  defp validate_bootstrap(provider) do
    case Map.get(provider, "bootstrap_clone", false) do
      false ->
        :ok

      true ->
        if get_in(provider, ["auth", "kind"]) == "github_app",
          do: :ok,
          else: {:error, :github_app_required_for_bootstrap_clone}

      _ ->
        {:error, :invalid_github_bootstrap_clone}
    end
  end

  @spec fetch_issues_by_states([String.t()]) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issues_by_states(states), do: client_module().fetch_issues_by_states(states)

  @spec fetch_issues_by_ids([String.t()]) :: {:ok, [Issue.t()]} | {:error, term()}
  def fetch_issues_by_ids(issue_ids), do: client_module().fetch_issues_by_ids(issue_ids)

  @spec agent_tool_specs() :: [map()]
  def agent_tool_specs, do: AgentTool.tool_specs()

  @spec execute_agent_tool(String.t(), term(), keyword()) :: map()
  def execute_agent_tool(tool, arguments, opts), do: AgentTool.execute(tool, arguments, opts)

  @spec prepare_workspace(Path.t(), Issue.t(), String.t() | nil) :: :ok | {:error, term()}
  def prepare_workspace(_workspace, _issue, worker_host) when is_binary(worker_host), do: :ok

  def prepare_workspace(workspace, _issue, nil) do
    GitPush.prepare_workspace(workspace, SymphonyPlus.Config.settings!().tracker)
  end

  @spec secret_environment_names(map()) :: [String.t()]
  def secret_environment_names(tracker_settings), do: Client.secret_environment_names(tracker_settings)

  defp client_module do
    Application.get_env(:symphony_plus, :github_client_module, Client)
  end

  defp validate_states(states, allowed_states, _missing_error) when is_list(states) do
    if Enum.all?(states, &(normalize_state(&1) in allowed_states)) do
      :ok
    else
      {:error, :invalid_github_states}
    end
  end

  defp validate_states(_states, _allowed_states, missing_error), do: {:error, missing_error}

  defp normalize_state(state) when is_binary(state), do: state |> String.trim() |> String.downcase()
  defp normalize_state(_state), do: ""
end
