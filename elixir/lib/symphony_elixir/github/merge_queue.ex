defmodule SymphonyElixir.GitHub.MergeQueue do
  @moduledoc """
  Serializes GitHub pull-request integration per repository and target branch.

  GitHub-visible admissions are durable truth. The process owns polling and an
  ephemeral active-operation cache only; rebuilding the same queues is safe.
  """

  use GenServer

  require Logger

  alias SymphonyElixir.GitHub.MergeQueue.Backend
  alias SymphonyElixir.GitHub.MergeQueue.State.Candidate
  alias SymphonyElixir.GitHub.MergeQueue.State.Entry

  @type queue_key :: {String.t(), String.t()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @spec status(GenServer.server()) :: map()
  def status(server \\ __MODULE__), do: GenServer.call(server, :status)

  @spec poll(GenServer.server()) :: :ok
  def poll(server \\ __MODULE__), do: GenServer.cast(server, :poll)

  @spec build_queues([Entry.t()]) :: %{optional(queue_key()) => [Entry.t()]}
  def build_queues(entries) do
    entries
    |> Enum.uniq_by(& &1.generation)
    |> Enum.group_by(&{&1.repository, &1.target_branch})
    |> Map.new(fn {key, queue} -> {key, Enum.sort_by(queue, &{&1.admission_sequence, &1.pr_number})} end)
  end

  @spec integration_order([Entry.t()], MapSet.t(pos_integer())) ::
          {:ok, [pos_integer()]} | {:blocked, %{optional(pos_integer()) => atom()}}
  def integration_order(entries, merged_prs) do
    by_number = Map.new(entries, &{&1.pr_number, &1})

    blockers =
      Enum.reduce(entries, %{}, fn entry, acc ->
        missing = Enum.reject(entry.dependencies, &(Map.has_key?(by_number, &1) or MapSet.member?(merged_prs, &1)))
        if missing == [], do: acc, else: Map.put(acc, entry.pr_number, :missing_dependency)
      end)

    if blockers == %{} do
      topo(entries, MapSet.to_list(merged_prs), [], [])
    else
      {:blocked, blockers}
    end
  end

  @spec actions([Entry.t()], map()) :: [tuple()]
  def actions(entries, context) do
    merged = Map.get(context, :merged_prs, MapSet.new())

    case integration_order(entries, merged) do
      {:ok, [head | _]} ->
        entry = Enum.find(entries, &(&1.pr_number == head))
        [{:advance, entry}]

      _ ->
        []
    end
  end

  @spec advance(Entry.t(), map()) ::
          {:merged, map()} | {:retry, term()} | {:update_required, term()} | {:blocked, term()}
  def advance(%Entry{} = entry, adapter) when is_map(adapter) do
    expected_head_sha = entry.candidate_sha || entry.source_head_sha

    with {:target, {:ok, target_sha}} <- {:target, adapter.target.(entry)},
         {:update, {:ok, candidate_sha}} <- {:update, adapter.update.(entry, expected_head_sha)},
         candidate = %Candidate{
           source_head_sha: entry.source_head_sha,
           target_sha: target_sha,
           candidate_sha: candidate_sha
         },
         :ok <- persist_candidate(adapter, entry, candidate),
         {:validate, {:ok, :passed}} <- {:validate, adapter.validate.(entry, candidate_sha)},
         {:refresh, {:ok, fresh}} <- {:refresh, adapter.refresh.(entry)},
         :ok <- freshness(candidate, fresh),
         {:merge, {:ok, :merged}} <- {:merge, adapter.merge.(entry, candidate_sha)} do
      {:merged, %{candidate_sha: candidate_sha, target_sha: target_sha}}
    else
      {:validate, {:error, {:checks_failed, _checks} = reason}} -> {:update_required, reason}
      {:update, {:error, :merge_conflict}} -> {:update_required, :merge_conflict}
      {:error, reason} -> {:retry, reason}
      {_step, {:error, reason}} -> classify_failure(reason)
      unexpected -> {:blocked, {:unexpected_provider_response, unexpected}}
    end
  end

  @spec backoff_ms(non_neg_integer(), pos_integer()) :: pos_integer()
  def backoff_ms(attempt, maximum) do
    min(trunc(:math.pow(2, max(attempt - 1, 0))) * 1_000, maximum)
  end

  @impl true
  def init(opts) do
    configured = configured_options()

    state = %{
      enabled: Keyword.get(opts, :enabled, configured.enabled),
      interval_ms: Keyword.get(opts, :interval_ms, configured.interval_ms),
      loader: Keyword.get(opts, :loader, &Backend.load/0),
      executor: Keyword.get(opts, :executor, &Backend.execute/1),
      max_retry_backoff_ms: Keyword.get(opts, :max_retry_backoff_ms, configured.max_retry_backoff_ms),
      reload_config?: not Keyword.has_key?(opts, :enabled),
      queues: %{},
      active_generations: MapSet.new(),
      retry_attempt: 0,
      next_delay: nil,
      timer: nil,
      last_error: nil
    }

    {:ok, schedule(state, Keyword.get(opts, :initial_delay, 0))}
  end

  @impl true
  def handle_call(:status, _from, state),
    do: {:reply, Map.take(state, [:enabled, :queues, :last_error, :retry_attempt, :next_delay]), state}

  @impl true
  def handle_cast(:poll, state), do: {:noreply, run_poll(state)}

  @impl true
  def handle_info(:poll, state) do
    updated = run_poll(state)
    {:noreply, schedule(updated, updated.next_delay)}
  end

  defp run_poll(state) do
    state = refresh_config(state)

    if state.enabled do
      run_enabled_poll(state)
    else
      %{state | queues: %{}, last_error: nil, retry_attempt: 0, next_delay: nil}
    end
  end

  defp run_enabled_poll(state) do
    case state.loader.() do
      {:ok, entries} ->
        queues = build_queues(entries)
        {active_generations, retry?} = advance_queues(queues, state)

        current_generations = entries |> Enum.map(& &1.generation) |> MapSet.new()

        %{
          state
          | queues: queues,
            active_generations: MapSet.intersection(active_generations, current_generations),
            retry_attempt: if(retry?, do: state.retry_attempt + 1, else: 0),
            next_delay:
              if(retry?,
                do: backoff_ms(state.retry_attempt + 1, state.max_retry_backoff_ms),
                else: nil
              ),
            last_error: nil
        }

      {:error, reason} ->
        Logger.warning("GitHub merge queue outcome=retry reason=#{inspect(reason)}")
        attempt = state.retry_attempt + 1

        %{
          state
          | last_error: reason,
            retry_attempt: attempt,
            next_delay: backoff_ms(attempt, state.max_retry_backoff_ms)
        }
    end
  end

  defp refresh_config(%{reload_config?: false} = state), do: state

  defp refresh_config(state) do
    configured = configured_options()

    %{
      state
      | enabled: configured.enabled,
        interval_ms: configured.interval_ms,
        max_retry_backoff_ms: configured.max_retry_backoff_ms
    }
  end

  defp advance_queues(queues, state) do
    Enum.reduce(queues, {state.active_generations, false}, fn {key, queue}, {active, retry?} ->
      {updated, queue_retry?} = advance_queue(key, queue, active, state.executor)
      {updated, retry? or queue_retry?}
    end)
  end

  defp advance_queue({repository, target}, queue, active, executor) do
    Enum.reduce(actions(queue, %{}), {active, false}, fn action, {inner_active, retry?} ->
      entry = List.first(queue)

      if MapSet.member?(inner_active, entry.generation) do
        {inner_active, retry?}
      else
        execute_action(repository, target, entry, action, inner_active, executor)
      end
    end)
  end

  defp execute_action(repository, target, entry, action, active, executor) do
    Logger.info("GitHub merge queue outcome=advance repository=#{repository} target=#{target} action=#{inspect(action)}")

    case executor.(action) do
      {outcome, _detail} when outcome in [:merged, :update_required, :blocked] ->
        {MapSet.put(active, entry.generation), false}

      _retryable ->
        {active, true}
    end
  end

  defp schedule(state, delay) do
    if state.timer, do: Process.cancel_timer(state.timer)
    %{state | timer: Process.send_after(self(), :poll, delay || state.interval_ms)}
  end

  defp configured_options do
    settings = SymphonyElixir.Config.merge_queue_settings()

    %{
      enabled: settings.enabled,
      interval_ms: settings.poll_interval_ms,
      max_retry_backoff_ms: settings.max_retry_backoff_ms
    }
  end

  @spec topo([Entry.t()], [pos_integer()], [pos_integer()], [pos_integer()]) ::
          {:ok, [pos_integer()]} | {:blocked, %{optional(pos_integer()) => :dependency_cycle}}
  defp topo(entries, merged, ordered, visited) do
    pending = Enum.reject(entries, &(&1.pr_number in visited))

    case Enum.find(pending, fn entry ->
           Enum.all?(entry.dependencies, &(&1 in merged or &1 in visited))
         end) do
      nil when pending == [] -> {:ok, Enum.reverse(ordered)}
      nil -> {:blocked, Map.new(pending, &{&1.pr_number, :dependency_cycle})}
      entry -> topo(entries, merged, [entry.pr_number | ordered], [entry.pr_number | visited])
    end
  end

  defp freshness(candidate, %{head_sha: head, target_sha: target, eligible: true}) do
    cond do
      head != candidate.candidate_sha -> {:error, :stale_head}
      target != candidate.target_sha -> {:error, :stale_target}
      true -> :ok
    end
  end

  defp freshness(_candidate, %{eligible: false}), do: {:error, :eligibility_lost}
  defp freshness(_candidate, _fresh), do: {:error, :unknown_freshness}

  defp persist_candidate(%{candidate: fun}, entry, candidate) when is_function(fun, 2),
    do: fun.(entry, candidate)

  defp persist_candidate(_adapter, _entry, _candidate), do: :ok

  defp classify_failure(:merge_conflict), do: {:update_required, :merge_conflict}
  defp classify_failure({:checks_failed, _checks} = reason), do: {:update_required, reason}
  defp classify_failure(reason) when reason in [:unknown_mergeability, :ambiguous_merge], do: {:blocked, reason}
  defp classify_failure(reason), do: {:retry, reason}
end
