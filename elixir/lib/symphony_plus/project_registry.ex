defmodule SymphonyPlus.ProjectRegistry do
  @moduledoc """
  Sole owner of the installation-local project registry.

  Records deliberately contain only a stable id and canonical workflow path. Mutations are
  serialized by this process and committed with a same-directory atomic rename.
  """

  use GenServer
  require Logger

  alias SymphonyPlus.Config
  alias SymphonyPlus.Config.Schema

  @version 1
  @type registration :: %{id: String.t(), workflow_path: Path.t()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec list(GenServer.server()) :: [registration()]
  def list(server \\ __MODULE__), do: GenServer.call(server, :list)

  @spec add(Path.t(), GenServer.server()) :: {:ok, registration(), :created | :existing} | {:error, term()}
  def add(path, server \\ __MODULE__), do: GenServer.call(server, {:add, path})

  @spec remove(String.t(), GenServer.server()) :: :ok | {:error, term()}
  def remove(id, server \\ __MODULE__), do: GenServer.call(server, {:remove, id})

  @spec get(String.t(), GenServer.server()) :: {:ok, registration()} | {:error, :not_found}
  def get(id, server \\ __MODULE__) do
    case Enum.find(list(server), &(&1.id == id)) do
      nil -> {:error, :not_found}
      registration -> {:ok, registration}
    end
  end

  @doc "Reads durable registrations without starting or mutating the service."
  @spec list_from_disk(Path.t()) :: {:ok, [registration()]} | {:error, term()}
  def list_from_disk(path \\ Config.project_registry_path()) do
    case load(path) do
      {:ok, registrations} -> {:ok, registrations |> Map.values() |> Enum.sort_by(& &1.id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :path, Config.project_registry_path())
    runtime_supervisor = Keyword.get(opts, :runtime_supervisor, SymphonyPlus.ProjectRuntimeSupervisor)

    case load(path) do
      {:ok, registrations} ->
        send(self(), :activate_all)
        {:ok, %{path: path, registrations: registrations, runtime_supervisor: runtime_supervisor}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, state.registrations |> Map.values() |> Enum.sort_by(& &1.id), state}
  end

  def handle_call({:add, raw_path}, _from, state) do
    with {:ok, workflow_path} <- canonical_workflow_path(raw_path),
         nil <- Enum.find(state.registrations, fn {_id, item} -> item.workflow_path == workflow_path end),
         :ok <- validate_workspace_isolation(workflow_path, state.registrations) do
      registration = %{id: project_id(workflow_path), workflow_path: workflow_path}
      registrations = Map.put(state.registrations, registration.id, registration)

      case persist(state.path, registrations) do
        :ok ->
          start_runtime(state.runtime_supervisor, registration)
          Logger.info("project_registry.added project_id=#{registration.id}")
          {:reply, {:ok, registration, :created}, %{state | registrations: registrations}}

        {:error, reason} ->
          {:reply, {:error, {:registry_write_failed, reason}}, state}
      end
    else
      {_id, %{id: _, workflow_path: _} = registration} ->
        {:reply, {:ok, registration, :existing}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:remove, id}, _from, state) do
    cond do
      not Map.has_key?(state.registrations, id) ->
        {:reply, :ok, state}

      not project_idle?(state.runtime_supervisor, id) ->
        {:reply, {:error, :project_busy}, state}

      true ->
        registrations = Map.delete(state.registrations, id)

        case persist(state.path, registrations) do
          :ok ->
            stop_runtime(state.runtime_supervisor, id)
            Logger.info("project_registry.removed project_id=#{id}")
            {:reply, :ok, %{state | registrations: registrations}}

          {:error, reason} ->
            {:reply, {:error, {:registry_write_failed, reason}}, state}
        end
    end
  end

  @impl true
  def handle_info(:activate_all, state) do
    Enum.each(state.registrations, fn {_id, registration} ->
      start_runtime(state.runtime_supervisor, registration)
    end)

    {:noreply, state}
  end

  defp start_runtime(nil, _registration), do: :ok
  defp start_runtime(supervisor, registration), do: SymphonyPlus.ProjectRuntimeSupervisor.start_project(registration, supervisor: supervisor)

  defp stop_runtime(nil, _id), do: :ok
  defp stop_runtime(supervisor, id), do: SymphonyPlus.ProjectRuntimeSupervisor.stop_project(id, supervisor)

  defp project_idle?(nil, _id), do: true
  defp project_idle?(supervisor, id), do: SymphonyPlus.ProjectRuntimeSupervisor.project_idle?(id, supervisor)

  defp canonical_workflow_path(path) when is_binary(path) do
    expanded = Path.expand(path)

    with {:ok, stat} <- File.stat(expanded),
         true <- stat.type == :regular || {:error, :not_a_regular_file},
         {:ok, canonical} <- resolve_final_symlink(expanded),
         {:ok, _workflow} <- SymphonyPlus.Workflow.load(canonical) do
      {:ok, canonical}
    else
      false -> {:error, :not_a_regular_file}
      {:error, reason} -> {:error, {:invalid_workflow, reason}}
    end
  end

  defp canonical_workflow_path(_), do: {:error, :invalid_workflow_path}

  defp resolve_final_symlink(path) do
    case :file.read_link_all(String.to_charlist(path)) do
      {:ok, target} -> {:ok, target |> List.to_string() |> Path.expand(Path.dirname(path))}
      {:error, :einval} -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_workspace_isolation(workflow_path, registrations) do
    with {:ok, candidate_root} <- workspace_root(workflow_path) do
      collision = Enum.find(registrations, &workspace_collision?(&1, candidate_root))

      if collision, do: {:error, :workspace_conflict}, else: :ok
    end
  end

  defp workspace_collision?({_id, registration}, candidate_root) do
    case workspace_root(registration.workflow_path) do
      {:ok, root} -> roots_overlap?(candidate_root, root)
      {:error, _reason} -> false
    end
  end

  defp workspace_root(workflow_path) do
    with {:ok, workflow} <- SymphonyPlus.Workflow.load(workflow_path),
         {:ok, settings} <- Schema.parse(workflow.config) do
      {:ok, Path.expand(settings.workspace.root, Path.dirname(workflow_path))}
    end
  end

  defp roots_overlap?(left, right) do
    left == right or String.starts_with?(left <> "/", right <> "/") or
      String.starts_with?(right <> "/", left <> "/")
  end

  defp project_id(path) do
    :crypto.hash(:sha256, path) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  defp load(path) do
    case File.read(path) do
      {:ok, ""} -> {:ok, %{}}
      {:ok, json} -> decode(json)
      {:error, :enoent} -> {:ok, %{}}
      {:error, reason} -> {:error, {:registry_read_failed, reason}}
    end
  end

  defp decode(json) do
    with {:ok, %{"version" => @version, "projects" => projects}} when is_list(projects) <- Jason.decode(json),
         {:ok, registrations} <- decode_projects(projects) do
      {:ok, registrations}
    else
      {:ok, %{"version" => version}} -> {:error, {:unsupported_registry_version, version}}
      {:ok, _} -> {:error, :malformed_registry}
      {:error, reason} -> {:error, {:malformed_registry, reason}}
    end
  end

  defp decode_projects(projects) do
    Enum.reduce_while(projects, {:ok, %{}}, fn
      %{"id" => id, "workflow_path" => path}, {:ok, acc} when is_binary(id) and is_binary(path) ->
        item = %{id: id, workflow_path: path}
        {:cont, {:ok, Map.put(acc, id, item)}}

      _, _ ->
        {:halt, {:error, :malformed_registry}}
    end)
  end

  defp persist(path, registrations) do
    directory = Path.dirname(path)
    temp = Path.join(directory, ".projects-#{System.unique_integer([:positive])}.tmp")
    payload = Jason.encode!(%{version: @version, projects: Map.values(registrations)})

    with :ok <- File.mkdir_p(directory),
         :ok <- File.write(temp, payload, [:binary, :sync]),
         :ok <- File.rename(temp, path) do
      :ok
    else
      {:error, reason} = error ->
        _ = File.rm(temp)
        if reason, do: error
    end
  end
end
