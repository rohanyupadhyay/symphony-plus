defmodule SymphonyPlus.ProjectRuntime do
  @moduledoc "Owns validation and lifecycle state for one registered project."
  use GenServer

  alias SymphonyPlus.Config.Schema

  @retry_ms 1_000
  @reason_limit 160

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    registration = Keyword.fetch!(opts, :registration)
    GenServer.start_link(__MODULE__, registration)
  end

  @spec snapshot(pid()) :: map()
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  @impl true
  def init(registration) do
    send(self(), :validate)
    {:ok, %{registration: registration, state: :starting, reason: nil, workflow: nil, settings: nil}}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, Map.take(state, [:registration, :state, :reason]), state}
  end

  @impl true
  def handle_info(:validate, state) do
    state = validate(state)
    if state.state == :unavailable, do: Process.send_after(self(), :validate, @retry_ms)
    {:noreply, state}
  end

  defp validate(state) do
    path = state.registration.workflow_path

    with {:ok, workflow} <- SymphonyPlus.Workflow.load(path),
         {:ok, settings} <- Schema.parse(workflow.config),
         :ok <- SymphonyPlus.Config.validate_settings(settings) do
      %{state | state: :active, reason: nil, workflow: workflow, settings: settings}
    else
      {:error, reason} ->
        safe = reason |> inspect() |> String.replace(~r/\s+/, " ") |> String.slice(0, @reason_limit)
        %{state | state: :unavailable, reason: safe, workflow: nil, settings: nil}
    end
  end
end
