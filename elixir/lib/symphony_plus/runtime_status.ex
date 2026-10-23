defmodule SymphonyPlus.RuntimeStatus do
  @moduledoc """
  Produces the mutually exclusive runtime-status read model used by observability surfaces.

  Mutable lifecycle state remains owned by the orchestrator. This module only classifies and
  sanitizes a completed snapshot.
  """

  @classifications [:running, :retrying, :quota_waiting, :blocked]
  @reason_limit 160
  @truncation_marker "…"
  @quota_projection_fields [
    :issue_id,
    :identifier,
    :issue_url,
    :state,
    :tracker_state,
    :worker_host,
    :workspace_path,
    :session_id,
    :blocked_at,
    :status,
    :harness,
    :pool_key,
    :renewal_at,
    :next_recheck_at,
    :native_context_available,
    :last_outcome,
    :updated_at,
    :reason,
    :error
  ]

  @type classification :: :running | :retrying | :quota_waiting | :blocked
  @type snapshot :: %{optional(atom()) => term()}

  @spec project(snapshot()) :: snapshot()
  def project(snapshot) when is_map(snapshot) do
    entries =
      @classifications
      |> Enum.flat_map(fn classification ->
        snapshot
        |> Map.get(classification, [])
        |> Enum.map(&normalize_entry(&1, classification))
      end)
      |> Enum.group_by(&identity/1)
      |> Enum.map(fn {_issue_id, candidates} -> select_entry(candidates) end)

    lists =
      Map.new(@classifications, fn classification ->
        {classification,
         entries
         |> Enum.filter(&(&1.classification == classification))
         |> Enum.map(&Map.delete(&1, :classification))
         |> Enum.sort_by(&to_string(Map.get(&1, :identifier) || Map.get(&1, :issue_id)))}
      end)

    counts = Map.new(@classifications, &{&1, length(Map.fetch!(lists, &1))})

    snapshot
    |> Map.merge(lists)
    |> Map.put(:counts, counts)
    |> Map.put_new(:update, update_status())
  end

  defp update_status do
    SymphonyPlus.UpdateManager.status()
  end

  @spec sanitize_reason(term(), String.t()) :: String.t()
  def sanitize_reason(value, fallback \\ "Operator action required") do
    reason =
      case value do
        value when is_binary(value) -> value
        nil -> ""
        value -> inspect(value)
      end
      |> String.replace(~r/[\x00-\x1F\x7F]+/u, " ")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    reason = if reason == "", do: fallback, else: reason
    graphemes = String.graphemes(reason)

    if length(graphemes) <= @reason_limit do
      reason
    else
      graphemes
      |> Enum.take(@reason_limit - 1)
      |> Enum.join()
      |> Kernel.<>(@truncation_marker)
    end
  end

  defp normalize_entry(entry, classification) do
    entry = if classification == :quota_waiting, do: Map.take(entry, @quota_projection_fields), else: entry
    classification = quota_classification(entry, classification)
    entry = Map.put(entry, :classification, classification)

    case classification do
      :blocked ->
        reason = Map.get(entry, :reason) || Map.get(entry, :error) || Map.get(entry, :last_outcome)

        entry
        |> Map.put(:error, sanitize_reason(reason))
        |> Map.put(:reason, sanitize_reason(reason))

      :quota_waiting ->
        timing = Map.get(entry, :renewal_at) || Map.get(entry, :next_recheck_at)
        Map.put(entry, :timing_cue, if(is_nil(timing), do: "Renewal time unavailable", else: nil))

      _ ->
        entry
    end
  end

  defp quota_classification(%{status: status}, :quota_waiting)
       when status in [:operator_blocked, "operator_blocked"],
       do: :blocked

  defp quota_classification(_entry, classification), do: classification

  defp identity(entry), do: Map.get(entry, :issue_id) || Map.fetch!(entry, :identifier)

  defp select_entry(candidates) do
    selected = Enum.max_by(candidates, &precedence(&1.classification))
    quota = Enum.find(candidates, &quota_candidate?/1)

    if selected.classification == :blocked and quota do
      selected
      |> Map.put(:quota_context, quota_context(quota))
      |> inherit_missing(quota)
    else
      selected
    end
  end

  defp quota_candidate?(entry), do: Map.has_key?(entry, :pool_key) or Map.has_key?(entry, :harness)

  defp quota_context(entry) do
    Map.take(entry, [
      :harness,
      :pool_key,
      :renewal_at,
      :next_recheck_at,
      :native_context_available,
      :last_outcome,
      :updated_at
    ])
  end

  defp inherit_missing(selected, source) do
    Enum.reduce([:identifier, :issue_url, :worker_host, :workspace_path], selected, fn key, acc ->
      if is_nil(Map.get(acc, key)), do: Map.put(acc, key, Map.get(source, key)), else: acc
    end)
  end

  defp precedence(:running), do: 1
  defp precedence(:retrying), do: 2
  defp precedence(:quota_waiting), do: 3
  defp precedence(:blocked), do: 4
end
