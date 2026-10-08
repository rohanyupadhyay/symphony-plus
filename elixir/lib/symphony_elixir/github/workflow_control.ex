defmodule SymphonyElixir.GitHub.WorkflowControl do
  @moduledoc """
  Encodes durable GitHub workflow checkpoints and derives the next dispatch trigger.

  Checkpoints are readable issue comments with an opaque, versioned marker. The
  GitHub adapter can therefore reconstruct waiting state after a restart without
  a Symphony-owned database.
  """

  @marker_regex ~r/<!-- symphony-control:v1:([^\s]+) -->/
  @states ~w(awaiting_input awaiting_approval review_pending awaiting_review merge_queued merge_validating merge_update_required merge_blocked merge_merged blocked)
  @gates ~w(spec plan implementation)
  @commands ~w(retry status cancel)
  @default_associations ~w(OWNER MEMBER COLLABORATOR)

  @type derived_state :: %{
          checkpoint: map() | nil,
          trigger: map() | nil,
          dispatchable: boolean()
        }

  @spec validate_settings(map()) :: :ok | {:error, atom()}
  def validate_settings(provider) when is_map(provider) do
    case Map.get(provider, "workflow_control") do
      nil ->
        :ok

      %{} = settings ->
        associations = Map.get(settings, "authorized_associations", @default_associations)

        cond do
          Map.get(settings, "enabled", false) not in [true, false] ->
            {:error, :invalid_github_workflow_control}

          not valid_associations?(associations) ->
            {:error, :invalid_github_workflow_associations}

          true ->
            :ok
        end

      _ ->
        {:error, :invalid_github_workflow_control}
    end
  end

  def validate_settings(_provider), do: {:error, :invalid_github_workflow_control}

  @spec enabled?(map()) :: boolean()
  def enabled?(provider) when is_map(provider) do
    get_in(provider, ["workflow_control", "enabled"]) == true
  end

  def enabled?(_provider), do: false

  @spec authorized_associations(map()) :: [String.t()]
  def authorized_associations(provider) when is_map(provider) do
    provider
    |> get_in(["workflow_control", "authorized_associations"])
    |> case do
      values when is_list(values) -> Enum.map(values, &normalize_association/1)
      _ -> @default_associations
    end
  end

  def authorized_associations(_provider), do: @default_associations

  @spec render_comment(map()) :: String.t()
  def render_comment(checkpoint) when is_map(checkpoint) do
    normalized = Map.put(checkpoint, "version", 1)
    marker = normalized |> Jason.encode!() |> Base.url_encode64(padding: false)

    [
      Map.get(normalized, "summary", "Symphony is waiting."),
      checkpoint_guidance(normalized),
      "<!-- symphony-control:v1:#{marker} -->"
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  @spec queue_admission(map(), map()) :: map()
  def queue_admission(review_checkpoint, attrs) when is_map(review_checkpoint) and is_map(attrs) do
    %{
      "state" => "merge_queued",
      "phase" => "merge_queue",
      "summary" => Map.get(attrs, "summary", "Pull request admitted to the serialized merge queue."),
      "pr_number" => review_checkpoint["pr_number"],
      "branch" => review_checkpoint["branch"],
      "head_sha" => review_checkpoint["head_sha"],
      "repository" => attrs["repository"],
      "target_branch" => attrs["target_branch"],
      "admission_sequence" => attrs["admission_sequence"],
      "dependencies" => Map.get(attrs, "dependencies", [])
    }
  end

  @spec queue_outcome(map(), atom(), term()) :: map()
  def queue_outcome(admission, kind, detail) when is_map(admission) and is_atom(kind) do
    state =
      case kind do
        :merged -> "merge_merged"
        :update_required -> "merge_update_required"
        _ -> "merge_blocked"
      end

    %{
      "state" => state,
      "phase" => "merge_queue",
      "summary" => "Merge queue outcome: #{kind} (#{inspect(detail)}).",
      "pr_number" => admission.pr_number,
      "repository" => admission.repository,
      "target_branch" => admission.target_branch,
      "head_sha" => admission.source_head_sha,
      "outcome" => Atom.to_string(kind),
      "reason" => inspect(detail),
      "recovery" => queue_recovery(kind)
    }
  end

  @spec queue_candidate(map(), String.t(), String.t()) :: map()
  def queue_candidate(admission, target_sha, candidate_sha)
      when is_map(admission) and is_binary(target_sha) and is_binary(candidate_sha) do
    %{
      "state" => "merge_validating",
      "phase" => "merge_queue",
      "summary" => "Validating pull request #{admission.pr_number} against #{admission.target_branch}.",
      "pr_number" => admission.pr_number,
      "repository" => admission.repository,
      "target_branch" => admission.target_branch,
      "head_sha" => admission.source_head_sha,
      "source_head_sha" => admission.source_head_sha,
      "target_sha" => target_sha,
      "candidate_sha" => candidate_sha,
      "admission_sequence" => admission.admission_sequence,
      "dependencies" => admission.dependencies
    }
  end

  @spec decode_checkpoint(String.t()) :: {:ok, map()} | :error
  def decode_checkpoint(body) when is_binary(body) do
    case Regex.scan(@marker_regex, body, capture: :all_but_first) |> List.last() do
      [encoded] -> decode_marker(encoded)
      _ -> :error
    end
  end

  def decode_checkpoint(_body), do: :error

  @spec valid_checkpoint(map()) :: :ok | {:error, atom()}
  def valid_checkpoint(checkpoint) when is_map(checkpoint) do
    state = checkpoint["state"]
    phase = checkpoint["phase"]
    summary = checkpoint["summary"]

    cond do
      state not in @states ->
        {:error, :invalid_workflow_state}

      not present?(phase) ->
        {:error, :invalid_workflow_phase}

      not present?(summary) ->
        {:error, :invalid_workflow_summary}

      true ->
        validate_checkpoint_state(checkpoint)
    end
  end

  def valid_checkpoint(_checkpoint), do: {:error, :invalid_workflow_checkpoint}

  defp validate_checkpoint_state(%{"state" => "awaiting_input", "prompt" => prompt}) do
    if present?(prompt), do: :ok, else: {:error, :missing_workflow_prompt}
  end

  defp validate_checkpoint_state(%{"state" => "awaiting_approval", "gate" => gate}) do
    if gate in @gates, do: :ok, else: {:error, :invalid_workflow_gate}
  end

  defp validate_checkpoint_state(%{"state" => "awaiting_review", "pr_number" => pr_number}) do
    if positive_integer?(pr_number), do: :ok, else: {:error, :invalid_workflow_pr_number}
  end

  defp validate_checkpoint_state(%{
         "state" => "review_pending",
         "phase" => "review",
         "pr_number" => pr_number,
         "branch" => branch,
         "head_sha" => head_sha
       }) do
    cond do
      not positive_integer?(pr_number) -> {:error, :invalid_workflow_pr_number}
      not present?(branch) -> {:error, :invalid_workflow_branch}
      not (is_binary(head_sha) and byte_size(head_sha) == 40) -> {:error, :invalid_workflow_head_sha}
      true -> :ok
    end
  end

  defp validate_checkpoint_state(%{"state" => "awaiting_input"}),
    do: {:error, :missing_workflow_prompt}

  defp validate_checkpoint_state(%{"state" => "awaiting_approval"}),
    do: {:error, :invalid_workflow_gate}

  defp validate_checkpoint_state(%{"state" => "awaiting_review"}),
    do: {:error, :invalid_workflow_pr_number}

  defp validate_checkpoint_state(%{"state" => "review_pending"}),
    do: {:error, :invalid_workflow_review_pending}

  defp validate_checkpoint_state(%{"state" => state} = checkpoint)
       when state in ["merge_queued", "merge_validating"] do
    with true <- positive_integer?(checkpoint["pr_number"]),
         true <- present?(checkpoint["repository"]),
         true <- present?(checkpoint["target_branch"]),
         true <- state != "merge_queued" or present?(checkpoint["branch"]),
         true <- is_binary(checkpoint["head_sha"]) and byte_size(checkpoint["head_sha"]) == 40,
         true <- is_integer(checkpoint["admission_sequence"]) and checkpoint["admission_sequence"] >= 0 do
      :ok
    else
      _ -> {:error, :invalid_merge_queue_admission}
    end
  end

  defp validate_checkpoint_state(_checkpoint), do: :ok

  @spec derive([map()], map(), [String.t()]) :: derived_state()
  def derive(comments, review_context, authorized_associations)
      when is_list(comments) and is_map(review_context) and is_list(authorized_associations) do
    derive(comments, review_context, authorized_associations, nil)
  end

  @spec derive([map()], map(), [String.t()], String.t() | nil) :: derived_state()
  def derive(comments, review_context, authorized_associations, trusted_bot_login)
      when is_list(comments) and is_map(review_context) and is_list(authorized_associations) do
    authorized = authorized_associations |> Enum.map(&normalize_association/1) |> MapSet.new()

    case latest_checkpoint(comments, authorized, trusted_bot_login) do
      nil ->
        %{checkpoint: nil, trigger: nil, dispatchable: true}

      %{comment: checkpoint_comment, checkpoint: checkpoint} ->
        trigger =
          derive_trigger(checkpoint, checkpoint_comment, comments, review_context, authorized)

        %{checkpoint: checkpoint, trigger: trigger, dispatchable: not is_nil(trigger)}
    end
  end

  defp decode_marker(encoded) do
    with {:ok, json} <- Base.url_decode64(encoded, padding: false),
         {:ok, %{"version" => 1} = checkpoint} <- Jason.decode(json),
         :ok <- valid_checkpoint(checkpoint) do
      {:ok, checkpoint}
    else
      _ -> :error
    end
  end

  defp checkpoint_guidance(%{"state" => "awaiting_input", "prompt" => prompt}), do: prompt

  defp checkpoint_guidance(%{"state" => "awaiting_approval", "gate" => gate}) do
    "Reply with `/symphony approve #{gate}` or `/symphony revise <instructions>`."
  end

  defp checkpoint_guidance(%{"state" => "awaiting_review"}) do
    "Symphony is waiting for pull-request review or merge. Use `/symphony revise <instructions>` to request another pass."
  end

  defp checkpoint_guidance(%{"state" => "review_pending"}) do
    "Symphony will automatically review and validate this pull request on the next scheduling opportunity."
  end

  defp checkpoint_guidance(%{"state" => "blocked", "prompt" => prompt}) when is_binary(prompt) do
    prompt <> "\n\nUse `/symphony retry`, `/symphony status`, or `/symphony cancel`."
  end

  defp checkpoint_guidance(%{"state" => "blocked"}) do
    "Use `/symphony retry`, `/symphony status`, or `/symphony cancel`."
  end

  defp checkpoint_guidance(%{"state" => "merge_queued"}) do
    "This pull request will be revalidated against the latest target branch when it reaches the queue head."
  end

  defp checkpoint_guidance(%{"state" => "merge_update_required"}) do
    "Update the pull request, restore current approval and checks, then request queue admission again."
  end

  defp checkpoint_guidance(_checkpoint), do: nil

  defp queue_recovery(:update_required), do: "Update the pull request and restore current approval and checks."
  defp queue_recovery(:blocked), do: "Resolve the reported blocker or retry after the provider recovers."
  defp queue_recovery(:merged), do: "No action required."
  defp queue_recovery(_kind), do: "Retry after inspecting the reported reason."

  defp latest_checkpoint(comments, authorized, trusted_bot_login) do
    comments
    |> Enum.filter(&(authorized?(&1, authorized) or trusted_bot?(&1, trusted_bot_login)))
    |> Enum.flat_map(fn comment ->
      case decode_checkpoint(comment["body"]) do
        {:ok, checkpoint} -> [%{comment: comment, checkpoint: checkpoint}]
        :error -> []
      end
    end)
    |> Enum.max_by(&event_id(&1.comment), fn -> nil end)
  end

  defp derive_trigger(checkpoint, checkpoint_comment, comments, review_context, authorized) do
    later_comments =
      comments
      |> Enum.filter(&(event_id(&1) > event_id(checkpoint_comment) and authorized?(&1, authorized)))
      |> Enum.reject(&marker_comment?/1)
      |> Enum.sort_by(&event_id/1)

    case checkpoint["state"] do
      "awaiting_input" ->
        latest_input_trigger(later_comments, checkpoint)

      "awaiting_approval" ->
        latest_valid_command(later_comments, checkpoint)

      "blocked" ->
        latest_valid_command(later_comments, checkpoint)

      "review_pending" ->
        automatic_review_trigger(checkpoint, review_context)

      "awaiting_review" ->
        review_trigger(checkpoint, later_comments, review_context, authorized)

      state when state in ["merge_queued", "merge_validating", "merge_update_required", "merge_blocked", "merge_merged"] ->
        nil
    end
  end

  defp automatic_review_trigger(checkpoint, context) do
    pull_request = Map.get(context, "pull_request", %{})

    if valid_automatic_review?(checkpoint, pull_request, context) do
      Map.take(checkpoint, ~w(pr_number branch head_sha))
      |> Map.put("kind", "automatic_review")
    end
  end

  defp valid_automatic_review?(checkpoint, pull_request, context) do
    open_pull_request?(pull_request) and pull_request["number"] == checkpoint["pr_number"] and
      matching_review_head?(checkpoint, pull_request, context) and
      safe_same_repository_head?(pull_request) and symphony_labeled?(pull_request)
  end

  defp open_pull_request?(pull_request),
    do: pull_request["state"] == "open" and pull_request["merged"] != true

  defp matching_review_head?(checkpoint, pull_request, context) do
    get_in(pull_request, ["head", "ref"]) == checkpoint["branch"] and
      get_in(pull_request, ["head", "sha"]) == checkpoint["head_sha"] and
      get_in(context, ["checks", "head_sha"]) == checkpoint["head_sha"]
  end

  defp safe_same_repository_head?(pull_request) do
    head_repo = get_in(pull_request, ["head", "repo"])
    base_repo = get_in(pull_request, ["base", "repo"])

    same_repository_identity?(head_repo, base_repo)
  end

  defp same_repository_identity?(%{"id" => head_id}, %{"id" => base_id})
       when is_integer(head_id) and is_integer(base_id),
       do: head_id == base_id

  defp same_repository_identity?(head_repo, base_repo) when is_map(head_repo) and is_map(base_repo),
    do: head_repo["full_name"] == base_repo["full_name"]

  defp same_repository_identity?(_head_repo, _base_repo) do
    false
  end

  defp symphony_labeled?(pull_request) do
    pull_request
    |> Map.get("labels", [])
    |> Enum.map(&label_name/1)
    |> Enum.member?("symphony")
  end

  defp label_name(%{"name" => name}) when is_binary(name),
    do: name |> String.trim() |> String.downcase()

  defp label_name(name) when is_binary(name), do: name |> String.trim() |> String.downcase()
  defp label_name(_label), do: ""

  defp latest_input_trigger(comments, checkpoint) do
    comments
    |> List.last()
    |> case do
      nil ->
        nil

      comment ->
        input_trigger(comment, checkpoint)
    end
  end

  defp input_trigger(comment, checkpoint) do
    command = command_event(comment)

    if command && valid_command_for_checkpoint?(command, checkpoint),
      do: command,
      else: event_payload(comment, "answer")
  end

  defp latest_valid_command(comments, checkpoint) do
    comments
    |> Enum.map(&command_event/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&valid_command_for_checkpoint?(&1, checkpoint))
    |> List.last()
  end

  defp valid_command_for_checkpoint?(%{"command" => "approve", "scope" => scope}, checkpoint) do
    checkpoint["state"] == "awaiting_approval" and checkpoint["gate"] == scope
  end

  defp valid_command_for_checkpoint?(%{"command" => "revise"}, checkpoint) do
    checkpoint["state"] in ["awaiting_approval", "awaiting_review", "blocked"]
  end

  defp valid_command_for_checkpoint?(%{"command" => command}, checkpoint)
       when command in @commands do
    case command do
      "retry" -> checkpoint["state"] == "blocked"
      _ -> true
    end
  end

  defp review_trigger(checkpoint, issue_comments, context, authorized) do
    pull_request = Map.get(context, "pull_request", %{})

    cond do
      pull_request["merged"] == true ->
        %{"kind" => "pull_request", "state" => "merged", "number" => pull_request["number"]}

      pull_request["state"] == "closed" ->
        %{"kind" => "pull_request", "state" => "closed", "number" => pull_request["number"]}

      true ->
        explicit_review_command(checkpoint, issue_comments, context, authorized) ||
          formal_review_trigger(checkpoint, context, authorized)
    end
  end

  defp explicit_review_command(checkpoint, issue_comments, context, authorized) do
    cursor = Map.get(checkpoint, "cursor", %{})

    pr_comments =
      [
        {Map.get(context, "conversation_comments", []), cursor["pr_comment_id"] || 0},
        {Map.get(context, "review_comments", []), cursor["review_comment_id"] || 0}
      ]
      |> Enum.flat_map(fn {events, minimum_id} ->
        Enum.filter(events, &(event_id(&1) > minimum_id and authorized?(&1, authorized)))
      end)

    (issue_comments ++ pr_comments)
    |> Enum.sort_by(&event_order/1)
    |> Enum.map(&command_event/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&valid_command_for_checkpoint?(&1, checkpoint))
    |> List.last()
  end

  defp formal_review_trigger(checkpoint, context, authorized) do
    minimum_id = get_in(checkpoint, ["cursor", "review_id"]) || 0

    actionable_reviews =
      context
      |> Map.get("reviews", [])
      |> Enum.filter(
        &(authorized?(&1, authorized) and
            normalize_review_state(&1["state"]) in ["approved", "changes_requested"])
      )

    new_review? = Enum.any?(actionable_reviews, &(event_id(&1) > minimum_id))

    latest_by_reviewer =
      actionable_reviews
      |> Enum.sort_by(&event_id/1)
      |> Enum.reduce(%{}, fn review, acc -> Map.put(acc, get_in(review, ["user", "login"]), review) end)
      |> Map.values()

    change_request =
      latest_by_reviewer
      |> Enum.filter(&(normalize_review_state(&1["state"]) == "changes_requested"))
      |> Enum.max_by(&event_id/1, fn -> nil end)

    approval =
      latest_by_reviewer
      |> Enum.filter(&(normalize_review_state(&1["state"]) == "approved"))
      |> Enum.max_by(&event_id/1, fn -> nil end)

    review = if new_review?, do: change_request || approval

    if review do
      review
      |> event_payload("review")
      |> Map.put("state", normalize_review_state(review["state"]))
    end
  end

  defp command_event(comment) do
    body = comment["body"] || ""

    parsed =
      cond do
        Regex.match?(~r/^\/symphony\s+approve\s+(spec|plan|implementation)\s*$/i, body) ->
          [_, scope] = Regex.run(~r/^\/symphony\s+approve\s+(spec|plan|implementation)\s*$/i, body)
          %{"command" => "approve", "scope" => String.downcase(scope)}

        captures =
            Regex.named_captures(
              ~r/^\/symphony\s+revise(?:\s+(?<scope>spec|plan|implementation))?(?:\s+(?<instructions>.+))?\s*$/is,
              body
            ) ->
          %{"command" => "revise"}
          |> maybe_put("scope", normalize_scope(captures["scope"]))
          |> maybe_put("instructions", normalize_text(captures["instructions"]))

        Regex.match?(~r/^\/symphony\s+(retry|status|cancel)\s*$/i, body) ->
          [_, command] = Regex.run(~r/^\/symphony\s+(retry|status|cancel)\s*$/i, body)
          %{"command" => String.downcase(command)}

        true ->
          nil
      end

    if parsed, do: Map.merge(event_payload(comment, "command"), parsed)
  end

  defp marker_comment?(comment), do: match?({:ok, _}, decode_checkpoint(comment["body"]))

  defp authorized?(event, authorized) do
    MapSet.member?(authorized, normalize_association(event["author_association"]))
  end

  defp trusted_bot?(event, trusted_bot_login) when is_binary(trusted_bot_login) do
    get_in(event, ["user", "login"]) == trusted_bot_login and
      get_in(event, ["user", "type"]) == "Bot"
  end

  defp trusted_bot?(_event, _trusted_bot_login), do: false

  defp event_payload(event, kind) do
    %{
      "kind" => kind,
      "id" => event_id(event),
      "body" => event["body"],
      "author" => get_in(event, ["user", "login"])
    }
  end

  defp event_id(event) when is_map(event) do
    case event["id"] do
      value when is_integer(value) -> value
      _ -> 0
    end
  end

  defp event_order(event) do
    created_at = if is_binary(event["created_at"]), do: event["created_at"], else: ""
    {created_at, event_id(event)}
  end

  defp normalize_review_state(value) when is_binary(value),
    do: value |> String.trim() |> String.downcase()

  defp normalize_review_state(_value), do: ""

  defp normalize_association(value) when is_binary(value),
    do: value |> String.trim() |> String.upcase()

  defp normalize_association(_value), do: ""

  defp normalize_scope(value) do
    case normalize_text(value) do
      nil -> nil
      normalized -> String.downcase(normalized)
    end
  end

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp positive_integer?(value), do: is_integer(value) and value > 0

  defp valid_associations?(values) when is_list(values) and values != [] do
    Enum.all?(values, &(normalize_association(&1) in @default_associations))
  end

  defp valid_associations?(_values), do: false
end
