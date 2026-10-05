defmodule SymphonyElixir.GitHub.MergeQueue.Backend do
  @moduledoc false

  require Logger

  alias SymphonyElixir.Config
  alias SymphonyElixir.GitHub.{Client, WorkflowControl}
  alias SymphonyElixir.GitHub.MergeQueue
  alias SymphonyElixir.GitHub.MergeQueue.State

  @spec load() :: {:ok, [State.Entry.t()]} | {:error, term()}
  def load do
    with {:ok, repo} <- configured_repo(),
         {:ok, issues} <- api("GET", "/repos/#{repo}/issues", %{"state" => "all", "labels" => "symphony"}, nil) do
      with {:ok, entries} <- load_issue_admissions(repo, Enum.reject(issues, &Map.has_key?(&1, "pull_request"))) do
        resolve_dependencies(repo, entries)
      end
    end
  end

  @spec execute(tuple()) ::
          {:merged, map()} | {:retry, term()} | {:update_required, term()} | {:blocked, term()}
  def execute({:advance, entry}) do
    result =
      with {:ok, fresh} <- refresh(entry.repository, entry),
           true <-
             (fresh.eligible and fresh.head_sha in [entry.source_head_sha, entry.candidate_sha]) or
               {:error, :eligibility_lost} do
        MergeQueue.advance(entry, adapter(entry.repository))
      else
        {:error, reason} -> {:blocked, reason}
      end

    Logger.info(
      "GitHub merge queue outcome=#{outcome(result)} repository=#{entry.repository} target=#{entry.target_branch} pr=#{entry.pr_number} source_head_sha=#{entry.source_head_sha} reason=#{inspect(result)}"
    )

    persist_outcome(entry, result)
  end

  def execute(_action), do: {:blocked, :invalid_action}

  defp admissions(repo, issue) do
    with {:ok, comments} <- api("GET", "/repos/#{repo}/issues/#{issue["number"]}/comments", %{}, nil) do
      latest =
        comments
        |> Enum.filter(&trusted_checkpoint?/1)
        |> Enum.sort_by(&(&1["id"] || 0), :desc)
        |> Enum.find(fn comment -> match?({:ok, _checkpoint}, WorkflowControl.decode_checkpoint(comment["body"] || "")) end)

      entries = if latest, do: decode_admission(latest, issue["number"]), else: []

      {:ok, entries}
    end
  end

  defp load_issue_admissions(repo, issues) do
    Enum.reduce_while(issues, {:ok, []}, fn issue, {:ok, acc} ->
      case admissions(repo, issue) do
        {:ok, entries} -> {:cont, {:ok, entries ++ acc}}
        error -> {:halt, error}
      end
    end)
  end

  defp resolve_dependencies(repo, entries) do
    queued = MapSet.new(entries, & &1.pr_number)

    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case unresolved_dependencies(repo, entry.dependencies, queued) do
        {:ok, dependencies} -> {:cont, {:ok, [%{entry | dependencies: dependencies} | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end)
  end

  defp unresolved_dependencies(repo, dependencies, queued) do
    Enum.reduce_while(dependencies, {:ok, []}, fn number, {:ok, acc} ->
      case dependency_state(repo, number, queued) do
        :satisfied -> {:cont, {:ok, acc}}
        :unresolved -> {:cont, {:ok, [number | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, unresolved} -> {:ok, Enum.reverse(unresolved)}
      error -> error
    end)
  end

  defp dependency_state(repo, number, queued) do
    if MapSet.member?(queued, number) do
      :unresolved
    else
      case Client.pull_request(repo, number) do
        {:ok, %{"merged" => true}} -> :satisfied
        {:ok, _pull_request} -> :unresolved
        {:error, {:github_api_status, 404, _}} -> :unresolved
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp decode_admission(comment, issue_number) do
    case WorkflowControl.decode_checkpoint(comment["body"] || "") do
      {:ok, %{"state" => state} = checkpoint} when state in ["merge_queued", "merge_validating"] ->
        build_admission(checkpoint, issue_number)

      {:ok, _terminal_checkpoint} ->
        false

      _ ->
        nil
    end
  end

  defp build_admission(checkpoint, issue_number) do
    attrs =
      checkpoint
      |> Map.put("originating_issue", issue_number)
      |> Map.put_new("source_head_sha", checkpoint["head_sha"])

    case State.new_entry(attrs) do
      {:ok, entry} -> [entry]
      _error -> []
    end
  end

  defp adapter(repo) do
    %{
      target: fn entry -> target_sha(repo, entry.target_branch) end,
      update: fn entry, expected -> update_candidate(repo, entry.pr_number, expected) end,
      candidate: fn entry, candidate -> persist_candidate_result(entry, candidate) end,
      validate: fn _entry, sha -> candidate_checks(repo, sha) end,
      refresh: fn entry -> refresh(repo, entry) end,
      merge: fn entry, sha -> merge(repo, entry.pr_number, sha) end
    }
  end

  defp target_sha(repo, branch) do
    with {:ok, payload} <- Client.ref(repo, branch),
         sha when is_binary(sha) <- get_in(payload, ["object", "sha"]) do
      {:ok, sha}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown_target}
    end
  end

  defp update_candidate(repo, number, expected) do
    with {:ok, _response} <- Client.update_branch(repo, number, expected),
         {:ok, pull_request} <- Client.pull_request(repo, number),
         sha when is_binary(sha) <- get_in(pull_request, ["head", "sha"]) do
      {:ok, sha}
    else
      {:error, {:github_api_status, 422, _}} -> reconcile_update(repo, number, expected)
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown_candidate}
    end
  end

  defp candidate_checks(repo, sha) do
    with {:ok, payload} <- Client.checks(repo, sha),
         {:ok, status_payload} <- Client.statuses(repo, sha) do
      runs = Map.get(payload, "check_runs", [])
      failures = Enum.filter(runs, &(&1["conclusion"] not in [nil, "success", "neutral", "skipped"]))
      statuses = Map.get(status_payload, "statuses", [])
      status_failures = Enum.filter(statuses, &(&1["state"] not in ["success", "pending"]))

      cond do
        failures != [] or status_failures != [] ->
          {:error, {:checks_failed, Enum.map(failures, & &1["name"]) ++ Enum.map(status_failures, & &1["context"])}}

        runs == [] and statuses == [] ->
          {:error, :checks_pending}

        Enum.any?(runs, &is_nil(&1["conclusion"])) or Enum.any?(statuses, &(&1["state"] == "pending")) ->
          {:error, :checks_pending}

        true ->
          {:ok, :passed}
      end
    end
  end

  defp refresh(repo, entry) do
    with {:ok, pull_request} <- Client.pull_request(repo, entry.pr_number),
         {:ok, target_sha} <- target_sha(repo, entry.target_branch),
         {:ok, reviews} <- Client.reviews(repo, entry.pr_number) do
      labels = pull_request |> Map.get("labels", []) |> Enum.map(&(&1["name"] || &1))

      latest_reviews = latest_reviews_by_author(reviews)

      eligible =
        pull_request["state"] == "open" and pull_request["merged"] != true and
          pull_request["mergeable"] != false and "symphony" in labels and
          Enum.any?(latest_reviews, &(&1["state"] == "APPROVED")) and
          not Enum.any?(latest_reviews, &(&1["state"] in ["CHANGES_REQUESTED", "DISMISSED"]))

      {:ok, %{head_sha: get_in(pull_request, ["head", "sha"]), target_sha: target_sha, eligible: eligible}}
    end
  end

  defp merge(repo, number, sha) do
    case Client.merge_pull_request(repo, number, sha) do
      {:ok, %{"merged" => true}} -> {:ok, :merged}
      {:ok, %{"merged" => false} = response} -> {:error, {:merge_rejected, response["message"]}}
      {:error, reason} -> reconcile_merge(repo, number, sha, reason)
    end
  end

  defp api(method, path, params, body) do
    case Client.request(method, path, params, body) do
      {:ok, %{status: status, body: response}} when status in 200..299 -> {:ok, response}
      {:ok, %{status: status}} -> {:error, {:github_api_status, status}}
      error -> error
    end
  end

  defp configured_repo do
    case get_in(Config.settings!().tracker.provider, ["repo"]) do
      repo when is_binary(repo) and repo != "" -> {:ok, repo}
      _ -> {:error, :missing_github_repo}
    end
  end

  defp trusted_checkpoint?(comment) do
    get_in(comment, ["user", "type"]) == "Bot" and
      (is_map(comment["performed_via_github_app"]) or String.ends_with?(get_in(comment, ["user", "login"]) || "", "[bot]"))
  end

  defp persist_outcome(_entry, {:retry, _reason} = result), do: result

  defp persist_outcome(entry, {kind, detail} = result) do
    checkpoint = WorkflowControl.queue_outcome(entry, kind, detail)
    body = %{"body" => WorkflowControl.render_comment(checkpoint)}

    case api("POST", "/repos/#{entry.repository}/issues/#{entry.originating_issue}/comments", %{}, body) do
      {:ok, _comment} -> result
      {:error, reason} -> {:retry, {:outcome_checkpoint_failed, reason}}
    end
  end

  defp persist_candidate_result(entry, candidate) do
    checkpoint = WorkflowControl.queue_candidate(entry, candidate.target_sha, candidate.candidate_sha)
    body = %{"body" => WorkflowControl.render_comment(checkpoint)}

    case api("POST", "/repos/#{entry.repository}/issues/#{entry.originating_issue}/comments", %{}, body) do
      {:ok, _comment} -> :ok
      {:error, reason} -> {:error, {:candidate_checkpoint_failed, reason}}
    end
  end

  defp reconcile_update(repo, number, expected) do
    with {:ok, pull_request} <- Client.pull_request(repo, number),
         head when is_binary(head) <- get_in(pull_request, ["head", "sha"]) do
      if head == expected, do: {:error, :merge_conflict}, else: {:ok, head}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unknown_candidate}
    end
  end

  defp reconcile_merge(repo, number, sha, original_reason) do
    case Client.pull_request(repo, number) do
      {:ok, %{"merged" => true, "merge_commit_sha" => merge_sha}} when is_binary(merge_sha) -> {:ok, :merged}
      {:ok, %{"head" => %{"sha" => ^sha}}} -> {:error, original_reason}
      {:ok, _pull_request} -> {:error, :ambiguous_merge}
      {:error, _reason} -> {:error, :ambiguous_merge}
    end
  end

  defp latest_reviews_by_author(reviews) do
    reviews
    |> Enum.sort_by(&(&1["id"] || 0))
    |> Enum.reduce(%{}, fn review, acc -> Map.put(acc, get_in(review, ["user", "login"]), review) end)
    |> Map.values()
  end

  defp outcome({kind, _detail}), do: kind
end
