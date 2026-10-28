defmodule SymphonyPlus.GitHub.DocumentationReview do
  @moduledoc "Host-stamped identities and source revision for independent documentation review."

  @spec required?(map()) :: boolean()
  def required?(provider), do: get_in(provider, ["workflow_control", "documentation_review_required"]) == true

  @spec stamp(map(), map() | nil, map(), keyword()) :: {:ok, map()} | {:error, atom()}
  def stamp(checkpoint, issue, provider, opts) do
    if required?(provider), do: stamp_required(checkpoint, issue, Keyword.get(opts, :trusted_thread_id)), else: {:ok, checkpoint}
  end

  defp stamp_required(%{"state" => "review_pending"} = checkpoint, _issue, thread) do
    if present?(thread) do
      {:ok, Map.put(checkpoint, "documentation_review", %{"version" => 1, "author_thread_id" => thread, "reviewed_source_sha" => checkpoint["head_sha"]})}
    else
      {:error, :documentation_review_thread_unavailable}
    end
  end

  defp stamp_required(%{"state" => "merge_queued"} = checkpoint, issue, thread) do
    control = if is_map(issue), do: get_in(issue.native_ref || %{}, ["workflow_control"]) || %{}, else: %{}
    previous = get_in(control, ["checkpoint", "documentation_review"]) || %{}
    trigger = control["trigger"] || %{}
    author = previous["author_thread_id"]

    with :ok <- validate_review_handoff(checkpoint, thread, author, trigger) do
      provenance = %{
        "version" => 1,
        "author_thread_id" => author,
        "reviewer_thread_id" => thread,
        "reviewed_source_sha" => trigger["head_sha"],
        "assessment" => checkpoint["documentation_assessment"]
      }

      {:ok, checkpoint |> Map.delete("documentation_assessment") |> Map.put("documentation_review", provenance)}
    end
  end

  defp stamp_required(checkpoint, _issue, _thread), do: {:ok, checkpoint}

  defp validate_review_handoff(checkpoint, thread, author, trigger) do
    cond do
      not present?(thread) ->
        {:error, :documentation_review_thread_unavailable}

      not present?(author) ->
        {:error, :documentation_review_author_unavailable}

      thread == author ->
        {:error, :documentation_review_not_independent}

      trigger["kind"] != "automatic_review" or trigger["head_sha"] != checkpoint["head_sha"] ->
        {:error, :documentation_review_source_mismatch}

      not valid_assessment?(checkpoint["documentation_assessment"]) ->
        {:error, :documentation_review_assessment_missing}

      true ->
        :ok
    end
  end

  @spec validate(term(), String.t()) :: :ok | {:error, atom()}
  def validate(%{"version" => 1} = provenance, source_sha) do
    cond do
      not present?(provenance["author_thread_id"]) or not present?(provenance["reviewer_thread_id"]) -> {:error, :documentation_review_missing}
      provenance["author_thread_id"] == provenance["reviewer_thread_id"] -> {:error, :documentation_review_not_independent}
      provenance["reviewed_source_sha"] != source_sha -> {:error, :documentation_review_source_mismatch}
      not valid_assessment?(provenance["assessment"]) -> {:error, :documentation_review_assessment_missing}
      true -> :ok
    end
  end

  def validate(_provenance, _source_sha), do: {:error, :documentation_review_missing}

  defp valid_assessment?(%{"summary" => summary, "evidence" => evidence} = assessment) do
    present?(summary) and byte_size(summary) <= 8_000 and is_list(evidence) and length(evidence) in 1..50 and
      Enum.all?(evidence, &(present?(&1) and byte_size(&1) <= 2_000)) and
      valid_limitations?(Map.get(assessment, "limitations", []))
  end

  defp valid_assessment?(_assessment), do: false
  defp valid_limitations?(values) when is_list(values), do: length(values) <= 50 and Enum.all?(values, &(present?(&1) and byte_size(&1) <= 2_000))
  defp valid_limitations?(_values), do: false
  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
