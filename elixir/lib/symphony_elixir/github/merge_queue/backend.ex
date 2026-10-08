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
         {:ok, app_id} <- configured_app_id(),
         {:ok, issues} <- api("GET", "/repos/#{repo}/issues", %{"state" => "all", "labels" => "symphony"}, nil) do
      with {:ok, entries} <-
             load_issue_admissions(repo, Enum.reject(issues, &Map.has_key?(&1, "pull_request")), app_id) do
        resolve_dependencies(repo, entries)
      end
    end
  end

  @spec execute(tuple()) ::
          {:merged, map()} | {:retry, term()} | {:update_required, term()} | {:blocked, term()}
  def execute({:advance, entry}) do
    result =
      with {:ok, fresh} <- refresh(entry.repository, entry),
           :ok <- admission_preflight(fresh, entry) do
        MergeQueue.advance(entry, adapter(entry.repository))
      else
        {:retry, reason} -> {:retry, reason}
        {:blocked, reason} -> {:blocked, reason}
        {:error, reason} -> {:blocked, reason}
      end

    Logger.info(
      "GitHub merge queue outcome=#{outcome(result)} repository=#{entry.repository} target=#{entry.target_branch} pr=#{entry.pr_number} source_head_sha=#{entry.source_head_sha} reason=#{inspect(result)}"
    )

    persist_outcome(entry, result)
  end

  def execute({:block_dependency, entry, reason}) do
    Logger.warning(
      "GitHub merge queue outcome=blocked repository=#{entry.repository} target=#{entry.target_branch} pr=#{entry.pr_number} source_head_sha=#{entry.source_head_sha} reason=#{reason} recovery=repair_dependency_declaration"
    )

    persist_outcome(entry, {:blocked, {:dependency, reason, "Repair the dependency declaration and re-enter the queue."}})
  end

  def execute(_action), do: {:blocked, :invalid_action}

  @doc false
  @spec admission_preflight(map(), State.Entry.t()) :: :ok | {:retry, term()} | {:blocked, term()}
  def admission_preflight(%{hold_reason: :human_changes_requested}, _entry),
    do: {:retry, :human_changes_requested}

  def admission_preflight(%{eligible: true, head_sha: head}, entry)
      when head in [entry.source_head_sha, entry.candidate_sha],
      do: :ok

  def admission_preflight(_fresh, _entry), do: {:blocked, :eligibility_lost}

  defp admissions(repo, issue, app_id) do
    with {:ok, comments} <-
           api("GET", "/repos/#{repo}/issues/#{issue["number"]}/comments", %{"per_page" => 100}, nil) do
      latest =
        comments
        |> Enum.filter(&checkpoint_trusted_for_app?(&1, app_id))
        |> Enum.sort_by(&(&1["id"] || 0), :desc)
        |> Enum.find(fn comment -> match?({:ok, _checkpoint}, WorkflowControl.decode_checkpoint(comment["body"] || "")) end)

      entries = if latest, do: decode_admission(latest, issue["number"]), else: []

      {:ok, entries}
    end
  end

  defp load_issue_admissions(repo, issues, app_id) do
    Enum.reduce_while(issues, {:ok, []}, fn issue, {:ok, acc} ->
      case admissions(repo, issue, app_id) do
        {:ok, entries} -> {:cont, {:ok, entries ++ acc}}
        error -> {:halt, error}
      end
    end)
  end

  defp resolve_dependencies(repo, entries) do
    queued = MapSet.new(entries, & &1.pr_number)

    resolve_dependencies_for_test(entries, fn entry, number ->
      dependency_state(repo, entry, number, queued)
    end)
  end

  @doc false
  @spec resolve_dependencies_for_test([State.Entry.t()], function()) :: {:ok, [State.Entry.t()]} | {:error, term()}
  def resolve_dependencies_for_test(entries, resolver) do
    resolved = Enum.map(entries, &resolve_entry_dependencies(&1, resolver))

    case Enum.find(resolved, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(resolved, fn {:ok, entry} -> entry end)}
      error -> error
    end
  end

  defp resolve_entry_dependencies(entry, resolver) do
    Enum.reduce_while(entry.dependencies, {:ok, [], nil}, fn number, {:ok, acc, nil} ->
      case resolver.(entry, number) do
        :satisfied -> {:cont, {:ok, acc, nil}}
        :unresolved -> {:cont, {:ok, [number | acc], nil}}
        {:blocked, reason} -> {:halt, {:ok, acc, reason}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, unresolved, blocker} ->
        {:ok, %{entry | dependencies: Enum.reverse(unresolved), dependency_blocker: blocker}}

      error ->
        error
    end)
  end

  defp dependency_state(_repo, entry, number, _queued) when number == entry.pr_number,
    do: {:blocked, :self_dependency}

  defp dependency_state(repo, _entry, number, queued) do
    if MapSet.member?(queued, number), do: :unresolved, else: provider_dependency_state(repo, number)
  end

  defp provider_dependency_state(repo, number) do
    dependency_state_for_test(repo, number, &Client.pull_request/2)
  end

  @doc false
  @spec dependency_state_for_test(String.t(), pos_integer(), function()) ::
          :satisfied | :unresolved | {:blocked, atom()} | {:error, term()}
  def dependency_state_for_test(repo, number, pull_request) do
    case pull_request.(repo, number) do
      {:ok, %{"base" => %{"repo" => %{"full_name" => dependency_repo}}}} when dependency_repo != repo ->
        {:blocked, :cross_repository_dependency}

      {:ok, %{"merged" => true}} ->
        :satisfied

      {:ok, %{"state" => "closed"}} ->
        {:blocked, :closed_unmerged_dependency}

      {:ok, _pull_request} ->
        :unresolved

      {:error, {:github_api_status, 404}} ->
        {:blocked, :missing_dependency}

      {:error, {:github_api_status, 404, _}} ->
        {:blocked, :missing_dependency}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec decode_admission(map(), pos_integer()) :: [State.Entry.t()]
  def decode_admission(comment, issue_number) do
    case WorkflowControl.decode_checkpoint(comment["body"] || "") do
      {:ok, %{"state" => state} = checkpoint} when state in ["merge_queued", "merge_validating"] ->
        build_admission(checkpoint, issue_number)

      {:ok, _terminal_checkpoint} ->
        []

      _ ->
        []
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
      eligible = eligible_for_autonomous_merge?(pull_request, reviews, entry)
      hold_reason = if WorkflowControl.autonomous_merge_allowed?(reviews), do: nil, else: :human_changes_requested

      {:ok,
       %{
         head_sha: get_in(pull_request, ["head", "sha"]),
         target_sha: target_sha,
         eligible: eligible,
         hold_reason: hold_reason
       }}
    end
  end

  @doc false
  @spec eligible_for_autonomous_merge?(map(), [map()], State.Entry.t()) :: boolean()
  def eligible_for_autonomous_merge?(pull_request, reviews, entry) do
    labels = pull_request |> Map.get("labels", []) |> Enum.map(&(&1["name"] || &1))

    pull_request["state"] == "open" and pull_request["merged"] != true and
      pull_request["mergeable"] != false and "symphony" in labels and
      get_in(pull_request, ["base", "ref"]) == entry.target_branch and
      same_repository_pull_request?(pull_request, entry.repository) and
      WorkflowControl.autonomous_merge_allowed?(reviews)
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

  defp configured_app_id do
    case get_in(Config.settings!().tracker.provider, ["auth", "app_id"]) do
      app_id when is_integer(app_id) and app_id > 0 ->
        {:ok, app_id}

      app_id when is_binary(app_id) ->
        case Integer.parse(app_id) do
          {parsed, ""} when parsed > 0 -> {:ok, parsed}
          _ -> {:error, :missing_github_app_id}
        end

      _ ->
        {:error, :missing_github_app_id}
    end
  end

  @doc false
  @spec checkpoint_trusted_for_app?(map(), pos_integer()) :: boolean()
  def checkpoint_trusted_for_app?(comment, app_id) do
    get_in(comment, ["user", "type"]) == "Bot" and
      get_in(comment, ["performed_via_github_app", "id"]) == app_id
  end

  defp same_repository_pull_request?(pull_request, repo) do
    head_repo = get_in(pull_request, ["head", "repo"])
    base_repo = get_in(pull_request, ["base", "repo"])

    is_map(head_repo) and is_map(base_repo) and head_repo["full_name"] == repo and
      base_repo["full_name"] == repo and same_repository_identity?(head_repo, base_repo)
  end

  defp same_repository_identity?(%{"id" => head_id}, %{"id" => base_id})
       when is_integer(head_id) and is_integer(base_id),
       do: head_id == base_id

  defp same_repository_identity?(head_repo, base_repo),
    do: head_repo["full_name"] == base_repo["full_name"]

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

  defp outcome({kind, _detail}), do: kind
end
