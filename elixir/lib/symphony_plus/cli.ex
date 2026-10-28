defmodule SymphonyPlus.CLI do
  @moduledoc """
  Escript entrypoint for running Symphony Plus with an explicit WORKFLOW.md path.
  """

  alias SymphonyPlus.GitHub.AppCLI
  alias SymphonyPlus.LogFile

  @acknowledgement_switch :i_understand_that_this_will_be_running_without_the_usual_guardrails
  @options %{
    service: [{@acknowledgement_switch, :boolean}, logs_root: :string, data_root: :string, port: :integer],
    list: [data_root: :string, format: :string],
    add: [service_url: :string],
    remove: [service_url: :string]
  }

  @doc "Authoritative option types consumed by each CLI parser."
  @spec options() :: %{atom() => keyword()}
  def options, do: @options

  @type ensure_started_result :: {:ok, [atom()]} | {:error, term()}
  @type deps :: %{
          optional(:add_project) => (String.t() -> {:ok, map(), :created | :existing} | {:error, term()}),
          file_regular?: (String.t() -> boolean()),
          set_workflow_file_path: (String.t() -> :ok | {:error, term()}),
          set_logs_root: (String.t() -> :ok | {:error, term()}),
          set_server_port_override: (non_neg_integer() | nil -> :ok | {:error, term()}),
          github_app_command: ([String.t()] -> :ok | {:error, term()}),
          ensure_all_started: (-> ensure_started_result())
        }

  @spec main([String.t()]) :: no_return()
  def main(args) do
    main(args, fn -> Application.ensure_all_started(:symphony_plus) end)
  end

  @doc false
  @spec main([String.t()], (-> ensure_started_result())) :: no_return()
  def main(args, ensure_all_started) do
    args = restart_arguments(args)
    Application.put_env(:symphony_plus, :launch_arguments, args)
    Application.put_env(:symphony_plus, :launch_cwd, File.cwd!())

    case evaluate(args, runtime_deps(ensure_all_started)) do
      :ok ->
        notify_update_ready()
        wait_for_shutdown()

      :command_ok ->
        System.halt(0)

      {:error, message} ->
        IO.puts(:stderr, format_error(message))
        System.halt(1)
    end
  end

  defp notify_update_ready do
    if path = System.get_env("SYMPHONY_PLUS_UPDATE_READY_FILE") do
      System.delete_env("SYMPHONY_PLUS_UPDATE_READY_FILE")
      File.write!(path, System.pid() <> "\n")
      File.chmod!(path, 0o600)
    end
  end

  defp restart_arguments([command | _] = args) when command in ["github-app", "projects"], do: args

  defp restart_arguments(args) do
    case System.get_env("SYMPHONY_PLUS_RESTART_ARGUMENTS") do
      nil ->
        args

      encoded ->
        System.delete_env("SYMPHONY_PLUS_RESTART_ARGUMENTS")
        restored = decode_restart_arguments(Jason.decode(encoded))
        restore_restart_cwd()
        restored
    end
  end

  defp restore_restart_cwd do
    if cwd = System.get_env("SYMPHONY_PLUS_RESTART_CWD") do
      System.delete_env("SYMPHONY_PLUS_RESTART_CWD")
      File.cd!(cwd)
    end
  end

  defp decode_restart_arguments({:ok, values}) when is_list(values) do
    if Enum.all?(values, &is_binary/1), do: values, else: raise(ArgumentError, "Invalid update restart arguments")
  end

  defp decode_restart_arguments(_decoded), do: raise(ArgumentError, "Invalid update restart arguments")

  @spec evaluate([String.t()]) :: :ok | :command_ok | {:error, term()}
  def evaluate(args), do: evaluate(args, runtime_deps())

  @spec evaluate([String.t()], deps()) :: :ok | :command_ok | {:error, term()}
  def evaluate(["github-app" | command_args], deps) do
    command = Map.get(deps, :github_app_command, &AppCLI.run/1)

    case command.(command_args) do
      :ok -> :command_ok
      {:error, _reason} = error -> error
    end
  end

  def evaluate(["projects", "list" | args], _deps) do
    case OptionParser.parse(args, strict: @options.list) do
      {opts, [], []} ->
        if root = opts[:data_root], do: Application.put_env(:symphony_plus, :data_root, Path.expand(root))

        list_projects(opts)

      _ ->
        {:error, usage_message()}
    end
  end

  def evaluate(["projects", "add", workflow_path | args], _deps) do
    with {opts, [], []} <- OptionParser.parse(args, strict: @options.add),
         {:ok, _started} <- Application.ensure_all_started(:req),
         {:ok, response} <-
           Req.post(projects_url(opts), json: %{workflow_path: Path.expand(workflow_path)}),
         true <- response.status in 200..299 do
      IO.puts(Jason.encode!(response.body))
      :command_ok
    else
      _ -> {:error, "Project add failed; ensure the local Symphony Plus service is running"}
    end
  end

  def evaluate(["projects", "remove", project_id | args], _deps) do
    with {opts, [], []} <- OptionParser.parse(args, strict: @options.remove),
         {:ok, _started} <- Application.ensure_all_started(:req),
         {:ok, response} <- Req.delete(projects_url(opts) <> "/" <> URI.encode(project_id)),
         true <- response.status in 200..299 do
      IO.puts(Jason.encode!(response.body))
      :command_ok
    else
      _ -> {:error, "Project removal failed; ensure the project is idle and the local service is running"}
    end
  end

  def evaluate(args, deps) do
    case OptionParser.parse(args, strict: @options.service) do
      {opts, [], []} ->
        with :ok <- require_guardrails_acknowledgement(opts),
             :ok <- maybe_set_logs_root(opts, deps),
             :ok <- maybe_set_data_root(opts),
             :ok <- maybe_set_server_port(opts, deps) do
          start_service(deps)
        end

      {opts, [workflow_path], []} ->
        with :ok <- require_guardrails_acknowledgement(opts),
             :ok <- maybe_set_logs_root(opts, deps),
             :ok <- maybe_set_data_root(opts),
             :ok <- maybe_set_server_port(opts, deps) do
          run(workflow_path, deps)
        end

      _ ->
        {:error, usage_message()}
    end
  end

  @spec run(String.t(), deps()) :: :ok | {:error, String.t()}
  def run(workflow_path, deps) do
    expanded_path = Path.expand(workflow_path)

    if deps.file_regular?.(expanded_path) do
      start_with_workflow(expanded_path, deps, Map.get(deps, :add_project))
    else
      {:error, "Workflow file not found: #{expanded_path}"}
    end
  end

  defp start_service(deps) do
    case deps.ensure_all_started.() do
      {:ok, _started_apps} -> :ok
      {:error, reason} -> {:error, "Failed to start Symphony Plus: #{inspect(reason)}"}
    end
  end

  @spec usage_message() :: String.t()
  defp usage_message do
    "Usage: symphony-plus [--logs-root <path>] [--data-root <path>] [--port <port>] [path-to-WORKFLOW.md] | projects list"
  end

  @spec runtime_deps() :: deps()
  @spec runtime_deps((-> ensure_started_result())) :: deps()
  defp runtime_deps(ensure_all_started \\ fn -> Application.ensure_all_started(:symphony_plus) end) do
    %{
      file_regular?: &File.regular?/1,
      set_workflow_file_path: &SymphonyPlus.Workflow.set_workflow_file_path/1,
      set_logs_root: &set_logs_root/1,
      set_server_port_override: &set_server_port_override/1,
      github_app_command: &AppCLI.run/1,
      add_project: &SymphonyPlus.ProjectRegistry.add/1,
      ensure_all_started: ensure_all_started
    }
  end

  defp format_error(message) when is_binary(message), do: message
  defp format_error(message), do: inspect(message)

  defp maybe_set_logs_root(opts, deps) do
    case Keyword.get_values(opts, :logs_root) do
      [] ->
        :ok

      values ->
        logs_root = values |> List.last() |> String.trim()

        if logs_root == "" do
          {:error, usage_message()}
        else
          :ok = deps.set_logs_root.(Path.expand(logs_root))
        end
    end
  end

  defp maybe_set_data_root(opts) do
    case Keyword.get(opts, :data_root) do
      nil -> :ok
      root when is_binary(root) and root != "" -> Application.put_env(:symphony_plus, :data_root, Path.expand(root))
      _ -> {:error, usage_message()}
    end
  end

  defp format_projects([]), do: "No projects registered."
  defp format_projects(projects), do: Enum.map_join(projects, "\n", &"#{&1.id}\t#{&1.workflow_path}")

  defp durable_projects do
    if Process.whereis(SymphonyPlus.ProjectRegistry) do
      {:ok, SymphonyPlus.ProjectRegistry.list()}
    else
      SymphonyPlus.ProjectRegistry.list_from_disk()
    end
  end

  defp list_projects(opts) do
    case durable_projects() do
      {:ok, projects} ->
        IO.puts(if opts[:format] == "json", do: Jason.encode!(projects), else: format_projects(projects))
        :command_ok

      {:error, reason} ->
        {:error, "Project registry is unavailable: #{inspect(reason)}"}
    end
  end

  defp start_with_workflow(expanded_path, deps, add_project) when is_function(add_project, 1) do
    with {:ok, _started_apps} <- deps.ensure_all_started.(),
         {:ok, _registration, _result} <- add_project.(expanded_path) do
      :ok
    else
      {:error, reason} -> startup_workflow_error(expanded_path, reason)
    end
  end

  defp start_with_workflow(expanded_path, deps, _add_project) do
    :ok = deps.set_workflow_file_path.(expanded_path)

    case deps.ensure_all_started.() do
      {:ok, _started_apps} -> :ok
      {:error, reason} -> startup_workflow_error(expanded_path, reason)
    end
  end

  defp startup_workflow_error(path, reason),
    do: {:error, "Failed to start Symphony Plus with workflow #{path}: #{inspect(reason)}"}

  defp projects_url(opts) do
    Keyword.get(opts, :service_url, "http://127.0.0.1:4000")
    |> String.trim_trailing("/")
    |> Kernel.<>("/api/v1/projects")
  end

  defp require_guardrails_acknowledgement(opts) do
    if Keyword.get(opts, @acknowledgement_switch, false) do
      :ok
    else
      {:error, acknowledgement_banner()}
    end
  end

  @spec acknowledgement_banner() :: String.t()
  defp acknowledgement_banner do
    lines = [
      "This Symphony Plus implementation is a low key engineering preview.",
      "Codex will run without any guardrails.",
      "SymphonyPlus is not a supported product and is presented as-is.",
      "To proceed, start with `--i-understand-that-this-will-be-running-without-the-usual-guardrails` CLI argument"
    ]

    width = Enum.max(Enum.map(lines, &String.length/1))
    border = String.duplicate("─", width + 2)
    top = "╭" <> border <> "╮"
    bottom = "╰" <> border <> "╯"
    spacer = "│ " <> String.duplicate(" ", width) <> " │"

    content =
      [
        top,
        spacer
        | Enum.map(lines, fn line ->
            "│ " <> String.pad_trailing(line, width) <> " │"
          end)
      ] ++ [spacer, bottom]

    [
      IO.ANSI.red(),
      IO.ANSI.bright(),
      Enum.join(content, "\n"),
      IO.ANSI.reset()
    ]
    |> IO.iodata_to_binary()
  end

  defp set_logs_root(logs_root) do
    Application.put_env(:symphony_plus, :log_file, LogFile.default_log_file(logs_root))
    :ok
  end

  defp maybe_set_server_port(opts, deps) do
    case Keyword.get_values(opts, :port) do
      [] ->
        :ok

      values ->
        port = List.last(values)

        if is_integer(port) and port >= 0 do
          :ok = deps.set_server_port_override.(port)
        else
          {:error, usage_message()}
        end
    end
  end

  defp set_server_port_override(port) when is_integer(port) and port >= 0 do
    Application.put_env(:symphony_plus, :server_port_override, port)
    :ok
  end

  @spec wait_for_shutdown() :: no_return()
  defp wait_for_shutdown do
    case Process.whereis(SymphonyPlus.Supervisor) do
      nil ->
        IO.puts(:stderr, "Symphony Plus supervisor is not running")
        System.halt(1)

      pid ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            case reason do
              :normal -> System.halt(0)
              _ -> System.halt(1)
            end
        end
    end
  end
end
