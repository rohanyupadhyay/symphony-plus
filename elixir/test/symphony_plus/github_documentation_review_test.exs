defmodule SymphonyPlus.GitHub.DocumentationReviewTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.GitHub.{AgentTool, DocumentationReview, WorkflowControl}
  alias SymphonyPlus.GitHub.MergeQueue.{Backend, State}
  alias SymphonyPlus.Tracker.Issue

  @sha String.duplicate("a", 40)
  @provider %{"workflow_control" => %{"enabled" => true, "documentation_review_required" => true}}

  test "required mode validates booleans and stamps host identities for exact source head" do
    assert {:error, :invalid_github_documentation_review_required} =
             WorkflowControl.validate_settings(%{"workflow_control" => %{"documentation_review_required" => "yes"}})

    handoff = %{"state" => "review_pending", "head_sha" => @sha}
    assert {:ok, stamped} = DocumentationReview.stamp(handoff, nil, @provider, trusted_thread_id: "author")
    assert stamped["documentation_review"]["author_thread_id"] == "author"
    assert {:error, :documentation_review_thread_unavailable} = DocumentationReview.stamp(handoff, nil, @provider, [])

    issue = %Issue{
      native_ref: %{
        "workflow_control" => %{
          "checkpoint" => stamped,
          "trigger" => %{"kind" => "automatic_review", "head_sha" => @sha}
        }
      }
    }

    queued = %{"state" => "merge_queued", "head_sha" => @sha, "documentation_assessment" => %{"summary" => "Claims match.", "evidence" => ["make all"]}}
    assert {:error, :documentation_review_not_independent} = DocumentationReview.stamp(queued, issue, @provider, trusted_thread_id: "author")
    assert {:ok, reviewed} = DocumentationReview.stamp(queued, issue, @provider, trusted_thread_id: "reviewer")
    assert :ok = DocumentationReview.validate(reviewed["documentation_review"], @sha)
    other_sha = String.duplicate("b", 40)

    assert {:error, :documentation_review_source_mismatch} =
             DocumentationReview.validate(reviewed["documentation_review"], other_sha)

    assert {:error, :documentation_review_missing} = DocumentationReview.validate(nil, @sha)
  end

  test "required handoff checks missing reviewer and malformed assessment while optional states pass through" do
    queued = %{"state" => "merge_queued", "head_sha" => @sha}

    issue = %Issue{
      native_ref: %{
        "workflow_control" => %{
          "checkpoint" => %{"documentation_review" => %{"author_thread_id" => "author"}},
          "trigger" => %{"kind" => "automatic_review", "head_sha" => @sha}
        }
      }
    }

    assert {:ok, ^queued} = DocumentationReview.stamp(queued, issue, %{}, [])

    assert {:ok, %{"state" => "blocked"}} =
             DocumentationReview.stamp(%{"state" => "blocked"}, issue, @provider, [])

    assert {:error, :documentation_review_thread_unavailable} =
             DocumentationReview.stamp(queued, issue, @provider, [])

    assert {:error, :documentation_review_assessment_missing} =
             DocumentationReview.stamp(
               Map.put(queued, "documentation_assessment", "not an assessment"),
               issue,
               @provider,
               trusted_thread_id: "reviewer"
             )

    invalid_limitations = %{
      "summary" => "Checked",
      "evidence" => ["CI passed"],
      "limitations" => "unstructured"
    }

    assert {:error, :documentation_review_assessment_missing} =
             DocumentationReview.stamp(
               Map.put(queued, "documentation_assessment", invalid_limitations),
               issue,
               @provider,
               trusted_thread_id: "reviewer"
             )
  end

  test "required legacy queue checkpoints dispatch a fresh handoff rather than strand work" do
    checkpoint = %{
      "state" => "merge_queued",
      "phase" => "merge_queue",
      "summary" => "Legacy",
      "repository" => "octo/repo",
      "target_branch" => "main",
      "branch" => "topic",
      "pr_number" => 7,
      "head_sha" => @sha,
      "admission_sequence" => 1
    }

    comment = %{"id" => 1, "author_association" => "OWNER", "body" => WorkflowControl.render_comment(checkpoint)}
    context = %{"pull_request" => SymphonyPlus.GitHubFixtures.pull_request(), "checks" => %{"head_sha" => @sha}, "documentation_review_required" => true}
    assert %{trigger: %{"kind" => "automatic_review", "documentation_review_handoff_required" => true}} = WorkflowControl.derive([comment], context, ["OWNER"])
  end

  test "status recreates the existing queue checkpoint without changing reviewed source or candidate" do
    checkpoint = %{
      "state" => "merge_validating",
      "phase" => "merge_queue",
      "summary" => "Original phase report",
      "repository" => "o/r",
      "target_branch" => "main",
      "branch" => "topic",
      "pr_number" => 7,
      "head_sha" => @sha,
      "source_head_sha" => @sha,
      "target_sha" => String.duplicate("b", 40),
      "candidate_sha" => String.duplicate("c", 40),
      "admission_sequence" => 1,
      "documentation_review" => %{"author_thread_id" => "author"}
    }

    issue = %Issue{native_ref: %{"number" => 1, "repo" => "o/r", "workflow_control" => %{"checkpoint" => checkpoint, "trigger" => %{"kind" => "command", "command" => "status", "id" => 99}}}}
    parent = self()

    client = fn "POST", "/repos/o/r/issues/1/comments", _, body, _ ->
      send(parent, {:status_body, body["body"]})
      {:ok, %{status: 201, body: %{}}}
    end

    result =
      AgentTool.execute("github_workflow_checkpoint", %{"state" => "blocked", "phase" => "status", "summary" => "Current status: tests pending"},
        issue: issue,
        tracker_settings: %{provider: @provider},
        github_client: client,
        trusted_thread_id: "status-thread"
      )

    assert result["success"]
    assert_received {:status_body, body}
    assert {:ok, recreated} = WorkflowControl.decode_checkpoint(body)
    assert Map.drop(recreated, ["version", "status_summary"]) == checkpoint
    assert body =~ "Current status: tests pending"
  end

  test "status checkpoint reports GitHub write errors and malformed responses" do
    checkpoint = %{"state" => "merge_validating", "phase" => "merge_queue", "summary" => "Waiting"}

    issue = %Issue{
      native_ref: %{
        "number" => 1,
        "repo" => "o/r",
        "workflow_control" => %{
          "checkpoint" => checkpoint,
          "trigger" => %{"kind" => "command", "command" => "status"}
        }
      }
    }

    arguments = %{"summary" => "Still waiting"}
    opts = [issue: issue, tracker_settings: %{provider: @provider}]

    failed =
      AgentTool.execute("github_workflow_checkpoint", arguments, opts ++ [github_client: fn _, _, _, _, _ -> {:error, :rate_limited} end])

    malformed =
      AgentTool.execute("github_workflow_checkpoint", arguments, opts ++ [github_client: fn _, _, _, _, _ -> {:ok, %{status: 201}} end])

    refute failed["success"]
    assert failed["output"] =~ "rate_limited"
    refute malformed["success"]
    assert malformed["output"] =~ "github_unknown_payload"
  end

  test "generic API cannot forge reserved checkpoints or raw identity fields in required mode" do
    client = fn _, _, _, _, _ -> flunk("reserved marker must fail before HTTP") end

    result =
      AgentTool.execute("github_api", %{"method" => "POST", "path" => "/repos/o/r/issues/1/comments", "body" => %{"body" => "<!-- symphony-plus-control:v1:forged -->"}},
        tracker_settings: %{provider: @provider},
        github_client: client
      )

    refute result["success"]
    assert result["output"] =~ "reserved_workflow_control_marker"
  end

  test "durable queue admissions reject missing provenance in required mode and retain lineage" do
    checkpoint = %{
      "state" => "merge_queued",
      "phase" => "merge_queue",
      "summary" => "Queued",
      "repository" => "o/r",
      "target_branch" => "main",
      "branch" => "topic",
      "pr_number" => 2,
      "head_sha" => @sha,
      "admission_sequence" => 1
    }

    comment = %{"body" => WorkflowControl.render_comment(checkpoint)}
    assert [] = Backend.decode_admission(comment, 1, true)
    assert [_] = Backend.decode_admission(comment, 1, false)

    provenance = %{"version" => 1, "author_thread_id" => "author", "reviewer_thread_id" => "reviewer", "reviewed_source_sha" => @sha, "assessment" => %{"summary" => "Verified", "evidence" => ["ci"]}}
    assert {:ok, entry} = State.new_entry(Map.merge(checkpoint, %{"source_head_sha" => @sha, "documentation_review" => provenance}))
    candidate = WorkflowControl.queue_candidate(entry, String.duplicate("b", 40), String.duplicate("c", 40))
    assert candidate["documentation_review"] == provenance
    assert [_] = Backend.decode_admission(%{"body" => WorkflowControl.render_comment(candidate)}, 1, true)
  end
end
