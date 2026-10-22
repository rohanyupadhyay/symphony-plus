defmodule SymphonyPlusWeb.ObservabilityApiController do
  @moduledoc """
  JSON API for Symphony Plus observability data.
  """

  use Phoenix.Controller, formats: [:json]

  alias Plug.Conn
  alias SymphonyPlusWeb.{Endpoint, Presenter}

  @spec add_project(Conn.t(), map()) :: Conn.t()
  def add_project(conn, %{"workflow_path" => workflow_path}) do
    case SymphonyPlus.ProjectRegistry.add(workflow_path) do
      {:ok, registration, :created} -> conn |> put_status(201) |> json(%{result: "created", project: registration})
      {:ok, registration, :existing} -> json(conn, %{result: "already_registered", project: registration})
      {:error, :workspace_conflict} -> error_response(conn, 409, "workspace_conflict", "Project workspace overlaps an existing project")
      {:error, {:registry_write_failed, _reason}} -> error_response(conn, 503, "registry_unavailable", "Project registry is unavailable")
      {:error, _reason} -> error_response(conn, 422, "invalid_workflow", "Workflow is missing or invalid")
    end
  end

  def add_project(conn, _params), do: error_response(conn, 422, "invalid_workflow", "workflow_path is required")

  @spec remove_project(Conn.t(), map()) :: Conn.t()
  def remove_project(conn, %{"project_id" => project_id}) do
    case SymphonyPlus.ProjectRegistry.get(project_id) do
      {:ok, _registration} ->
        case SymphonyPlus.ProjectRegistry.remove(project_id) do
          :ok -> json(conn, %{result: "removed", project_id: project_id})
          {:error, :project_busy} -> error_response(conn, 409, "project_busy", "Project has retained work")
          {:error, {:registry_write_failed, _reason}} -> error_response(conn, 503, "registry_unavailable", "Project registry is unavailable")
        end

      {:error, :not_found} ->
        error_response(conn, 404, "project_not_found", "Project not found")
    end
  end

  @spec state(Conn.t(), map()) :: Conn.t()
  def state(conn, _params) do
    json(conn, Presenter.state_payload(orchestrator(), snapshot_timeout_ms()))
  end

  @spec issue(Conn.t(), map()) :: Conn.t()
  def issue(conn, %{"issue_identifier" => issue_identifier}) do
    case Presenter.issue_payload(issue_identifier, orchestrator(), snapshot_timeout_ms()) do
      {:ok, payload} ->
        json(conn, payload)

      {:error, :issue_not_found} ->
        error_response(conn, 404, "issue_not_found", "Issue not found")
    end
  end

  @spec refresh(Conn.t(), map()) :: Conn.t()
  def refresh(conn, _params) do
    case Presenter.refresh_payload(orchestrator()) do
      {:ok, payload} ->
        conn
        |> put_status(202)
        |> json(payload)

      {:error, :unavailable} ->
        error_response(conn, 503, "orchestrator_unavailable", "Orchestrator is unavailable")
    end
  end

  @spec method_not_allowed(Conn.t(), map()) :: Conn.t()
  def method_not_allowed(conn, _params) do
    error_response(conn, 405, "method_not_allowed", "Method not allowed")
  end

  @spec not_found(Conn.t(), map()) :: Conn.t()
  def not_found(conn, _params) do
    error_response(conn, 404, "not_found", "Route not found")
  end

  defp error_response(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end

  defp orchestrator do
    Endpoint.config(:orchestrator) || SymphonyPlus.Orchestrator
  end

  defp snapshot_timeout_ms do
    Endpoint.config(:snapshot_timeout_ms) || 15_000
  end
end
