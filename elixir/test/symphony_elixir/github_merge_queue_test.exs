defmodule SymphonyElixir.GitHub.MergeQueueTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.GitHub.MergeQueue
  alias SymphonyElixir.GitHub.MergeQueue.Backend
  alias SymphonyElixir.GitHub.MergeQueue.State
  alias SymphonyElixir.GitHub.WorkflowControl

  @sha_a String.duplicate("a", 40)
  @sha_b String.duplicate("b", 40)

  test "loader ignores issues whose latest trusted checkpoint is not queued" do
    terminal = %{
      "id" => 99,
      "body" =>
        WorkflowControl.render_comment(%{
          "state" => "blocked",
          "phase" => "review",
          "summary" => "Waiting for operator recovery."
        })
    }

    assert [] = Backend.decode_admission(terminal, 11)
  end

  test "autonomous merge eligibility needs no approval and holds active human change requests" do
    queued = entry(2, @sha_b, 1)

    pull_request = %{
      "state" => "open",
      "merged" => false,
      "mergeable" => true,
      "labels" => [%{"name" => "symphony"}],
      "head" => %{"repo" => %{"id" => 123, "full_name" => "octo/repo"}},
      "base" => %{"ref" => "main", "repo" => %{"id" => 123, "full_name" => "octo/repo"}}
    }

    assert Backend.eligible_for_autonomous_merge?(pull_request, [], queued)

    assert Backend.eligible_for_autonomous_merge?(
             pull_request,
             [%{"id" => 1, "state" => "APPROVED", "user" => %{"login" => "alice"}}],
             queued
           )

    refute Backend.eligible_for_autonomous_merge?(
             pull_request,
             [%{"id" => 1, "state" => "CHANGES_REQUESTED", "user" => %{"login" => "alice"}}],
             queued
           )

    refute Backend.eligible_for_autonomous_merge?(put_in(pull_request, ["base", "ref"], "release"), [], queued)
    refute Backend.eligible_for_autonomous_merge?(put_in(pull_request, ["head", "repo", "id"], 456), [], queued)
  end

  test "durable admissions trust only the configured GitHub App" do
    trusted = %{
      "user" => %{"type" => "Bot", "login" => "symphony-plus[bot]"},
      "performed_via_github_app" => %{"id" => 42}
    }

    assert Backend.checkpoint_trusted_for_app?(trusted, 42)
    refute Backend.checkpoint_trusted_for_app?(trusted, 99)

    refute Backend.checkpoint_trusted_for_app?(
             %{"user" => %{"type" => "Bot", "login" => "foreign[bot]"}},
             42
           )
  end

  test "human change request preflight retries without consuming the queue generation" do
    queued = entry(2, @sha_b, 1)

    assert {:retry, :human_changes_requested} =
             Backend.admission_preflight(
               %{eligible: false, hold_reason: :human_changes_requested, head_sha: @sha_b},
               queued
             )

    assert :ok = Backend.admission_preflight(%{eligible: true, head_sha: @sha_b}, queued)
  end

  test "orders admissions stably, deduplicates generations, and isolates queue keys" do
    assert [] = MergeQueue.actions([], %{})

    entries = [entry(3, @sha_a, 2), entry(2, @sha_b, 1), entry(2, @sha_b, 1), entry(1, @sha_a, 1, "release")]
    queues = MergeQueue.build_queues(entries)

    assert Enum.map(queues[{"octo/repo", "main"}], & &1.pr_number) == [2, 3]
    assert Enum.map(queues[{"octo/repo", "release"}], & &1.pr_number) == [1]
  end

  test "dependencies take precedence and cycles are actionable" do
    prerequisite = entry(4, @sha_a, 2)
    dependent = entry(5, @sha_b, 1, "main", [4])

    assert {:ok, [4, 5]} = MergeQueue.integration_order([dependent, prerequisite], MapSet.new())

    assert {:blocked, %{4 => :dependency_cycle, 5 => :dependency_cycle}} =
             MergeQueue.integration_order([dependent, entry(6, @sha_a, 2, "main", [5]) |> Map.put(:pr_number, 4)], MapSet.new())

    assert [{:block_dependency, %{pr_number: 7}, :missing_dependency}] =
             MergeQueue.actions([entry(7, @sha_a, 1, "main", [99])], %{})
  end

  test "coordinator advances and tracks the selected prerequisite generation" do
    owner = self()
    prerequisite = entry(4, @sha_a, 2)
    dependent = entry(5, @sha_b, 1, "main", [4])
    {:ok, loads} = Agent.start_link(fn -> 0 end)

    loader = fn ->
      call = Agent.get_and_update(loads, &{&1, &1 + 1})
      if call == 0, do: {:ok, [dependent, prerequisite]}, else: {:ok, [prerequisite]}
    end

    {:ok, queue} =
      MergeQueue.start_link(
        name: nil,
        enabled: true,
        loader: loader,
        executor: fn action ->
          send(owner, {:action, action})
          {:merged, %{}}
        end,
        initial_delay: 60_000
      )

    MergeQueue.poll(queue)
    assert_receive {:action, {:advance, %{pr_number: 4}}}
    refute_receive {:action, {:advance, %{pr_number: 5}}}

    MergeQueue.poll(queue)
    refute_receive {:action, _}
  end

  test "dependency blockers are actionable while independent work advances" do
    independent = entry(2, @sha_a, 3)
    missing = %{entry(7, @sha_b, 1, "main", [99]) | dependency_blocker: :missing_dependency}
    closed = %{entry(8, @sha_a, 2, "main", [98]) | dependency_blocker: :closed_unmerged_dependency}

    assert [
             {:block_dependency, %{pr_number: 7}, :missing_dependency},
             {:block_dependency, %{pr_number: 8}, :closed_unmerged_dependency},
             {:advance, %{pr_number: 2}}
           ] = MergeQueue.actions([missing, closed, independent], %{})
  end

  test "cyclic dependencies are blocked without holding independent work" do
    first = entry(4, @sha_a, 1, "main", [5])
    second = entry(5, @sha_b, 2, "main", [4])
    independent = entry(6, @sha_a, 3)

    assert [
             {:block_dependency, %{pr_number: 4}, :dependency_cycle},
             {:block_dependency, %{pr_number: 5}, :dependency_cycle},
             {:advance, %{pr_number: 6}}
           ] = MergeQueue.actions([first, second, independent], %{})
  end

  test "coordinator persists dependency blockers and advances independent work in one poll" do
    owner = self()
    blocked = entry(7, @sha_b, 1, "main", [99])
    independent = entry(2, @sha_a, 2)

    loader = fn ->
      Backend.resolve_dependencies_for_test([blocked, independent], fn
        _entry, 99 -> {:blocked, :missing_dependency}
      end)
    end

    {:ok, queue} =
      MergeQueue.start_link(
        name: nil,
        enabled: true,
        loader: loader,
        executor: fn action ->
          send(owner, {:action, action})

          case action do
            {:block_dependency, _, reason} -> {:blocked, reason}
            {:advance, _} -> {:merged, %{}}
          end
        end,
        initial_delay: 60_000
      )

    MergeQueue.poll(queue)
    assert_receive {:action, {:block_dependency, %{pr_number: 7}, :missing_dependency}}
    assert_receive {:action, {:advance, %{pr_number: 2}}}
  end

  test "dependency resolution classifies provider-visible invalid relationships" do
    cases = [
      {7, :self_dependency},
      {8, :missing_dependency},
      {9, :cross_repository_dependency},
      {10, :closed_unmerged_dependency}
    ]

    Enum.each(cases, fn {dependency, reason} ->
      entries = [entry(7, @sha_a, 1, "main", [dependency])]
      resolver = fn _entry, ^dependency -> {:blocked, reason} end

      assert {:ok, [%{dependency_blocker: ^reason}]} =
               Backend.resolve_dependencies_for_test(entries, resolver)
    end)
  end

  test "provider dependency classification distinguishes actionable states" do
    pull = fn
      _repo, 8 -> {:error, {:github_api_status, 404}}
      _repo, 9 -> {:ok, %{"base" => %{"repo" => %{"full_name" => "other/repo"}}, "state" => "open"}}
      _repo, 10 -> {:ok, %{"base" => %{"repo" => %{"full_name" => "octo/repo"}}, "state" => "closed"}}
      _repo, 11 -> {:ok, %{"base" => %{"repo" => %{"full_name" => "octo/repo"}}, "merged" => true}}
    end

    assert {:blocked, :missing_dependency} = Backend.dependency_state_for_test("octo/repo", 8, pull)
    assert {:blocked, :cross_repository_dependency} = Backend.dependency_state_for_test("octo/repo", 9, pull)
    assert {:blocked, :closed_unmerged_dependency} = Backend.dependency_state_for_test("octo/repo", 10, pull)
    assert :satisfied = Backend.dependency_state_for_test("octo/repo", 11, pull)
  end

  test "non-head target movement never produces branch updates" do
    assert [{:advance, %{pr_number: 2}}] =
             MergeQueue.actions([entry(2, @sha_b, 1), entry(3, @sha_a, 2)], %{})
  end

  test "active head merges only after exact candidate and target freshness" do
    candidate_sha = String.duplicate("c", 40)
    target_sha = String.duplicate("d", 40)
    owner = self()

    adapter = %{
      target: fn _entry -> {:ok, target_sha} end,
      update: fn _entry, expected ->
        send(owner, {:updated, expected})
        {:ok, candidate_sha}
      end,
      validate: fn _entry, ^candidate_sha -> {:ok, :passed} end,
      refresh: fn _entry -> {:ok, %{head_sha: candidate_sha, target_sha: target_sha, eligible: true}} end,
      merge: fn _entry, expected ->
        send(owner, {:merged, expected})
        {:ok, :merged}
      end
    }

    assert {:merged, %{candidate_sha: ^candidate_sha}} = MergeQueue.advance(entry(2, @sha_b, 1), adapter)
    assert_receive {:updated, @sha_b}
    assert_receive {:merged, ^candidate_sha}
  end

  test "recovered candidate uses its durable candidate head for the next guarded update" do
    old_candidate = String.duplicate("c", 40)
    new_candidate = String.duplicate("d", 40)
    target_sha = String.duplicate("e", 40)
    owner = self()
    recovered = %{entry(2, @sha_b, 1) | candidate_sha: old_candidate, target_sha: @sha_a}

    adapter = %{
      target: fn _entry -> {:ok, target_sha} end,
      update: fn _entry, expected ->
        send(owner, {:updated, expected})
        {:ok, new_candidate}
      end,
      validate: fn _entry, ^new_candidate -> {:ok, :passed} end,
      refresh: fn _entry -> {:ok, %{head_sha: new_candidate, target_sha: target_sha, eligible: true}} end,
      merge: fn _entry, ^new_candidate -> {:ok, :merged} end
    }

    assert {:merged, %{candidate_sha: ^new_candidate}} = MergeQueue.advance(recovered, adapter)
    assert_receive {:updated, ^old_candidate}
  end

  test "stale targets retry and deterministic validation failures request updates" do
    candidate_sha = String.duplicate("c", 40)
    target_sha = String.duplicate("d", 40)

    common = %{
      target: fn _ -> {:ok, target_sha} end,
      update: fn _, _ -> {:ok, candidate_sha} end,
      merge: fn _, _ -> flunk("stale or failed candidates must never merge") end
    }

    stale =
      Map.merge(common, %{
        validate: fn _, _ -> {:ok, :passed} end,
        refresh: fn _ -> {:ok, %{head_sha: candidate_sha, target_sha: @sha_a, eligible: true}} end
      })

    failed =
      Map.merge(common, %{
        validate: fn _, _ -> {:error, {:checks_failed, ["test"]}} end,
        refresh: fn _ -> flunk("failed checks do not need freshness evaluation") end
      })

    assert {:retry, :stale_target} = MergeQueue.advance(entry(2, @sha_b, 1), stale)

    assert {:update_required, {:checks_failed, ["test"]}} =
             MergeQueue.advance(entry(2, @sha_b, 1), failed)

    lost_eligibility = %{stale | refresh: fn _ -> {:ok, %{eligible: false}} end}
    assert {:retry, :eligibility_lost} = MergeQueue.advance(entry(2, @sha_b, 1), lost_eligibility)

    unknown_freshness = %{stale | refresh: fn _ -> {:ok, %{}} end}
    assert {:retry, :unknown_freshness} = MergeQueue.advance(entry(2, @sha_b, 1), unknown_freshness)
  end

  test "classifies provider outcomes and candidate checkpoint failures" do
    target_sha = String.duplicate("d", 40)
    candidate_sha = String.duplicate("c", 40)

    base = %{
      target: fn _ -> {:ok, target_sha} end,
      update: fn _, _ -> {:ok, candidate_sha} end,
      validate: fn _, _ -> {:ok, :passed} end,
      refresh: fn _ -> {:ok, %{head_sha: candidate_sha, target_sha: target_sha, eligible: true}} end,
      merge: fn _, _ -> {:ok, :merged} end
    }

    assert {:update_required, :merge_conflict} =
             MergeQueue.advance(entry(2, @sha_b, 1), %{base | update: fn _, _ -> {:error, :merge_conflict} end})

    assert {:blocked, :ambiguous_merge} =
             MergeQueue.advance(entry(2, @sha_b, 1), %{base | validate: fn _, _ -> {:error, :ambiguous_merge} end})

    assert {:update_required, :merge_conflict} =
             MergeQueue.advance(entry(2, @sha_b, 1), %{base | validate: fn _, _ -> {:error, :merge_conflict} end})

    assert {:update_required, {:checks_failed, ["test"]}} =
             MergeQueue.advance(entry(2, @sha_b, 1), %{
               base
               | refresh: fn _ -> {:error, {:checks_failed, ["test"]}} end
             })

    assert {:retry, :candidate_write_failed} =
             MergeQueue.advance(entry(2, @sha_b, 1), Map.put(base, :candidate, fn _, _ -> {:error, :candidate_write_failed} end))

    assert {:blocked, {:unexpected_provider_response, {:validate, {:ok, :unknown}}}} =
             MergeQueue.advance(entry(2, @sha_b, 1), %{base | validate: fn _, _ -> {:ok, :unknown} end})
  end

  test "provider failures remain retryable instead of requiring author updates" do
    adapter = %{
      target: fn _ -> {:error, :rate_limited} end,
      update: fn _, _ -> flunk("must stop after provider failure") end,
      validate: fn _, _ -> flunk("must stop after provider failure") end,
      refresh: fn _ -> flunk("must stop after provider failure") end,
      merge: fn _, _ -> flunk("must stop after provider failure") end
    }

    assert {:retry, :rate_limited} = MergeQueue.advance(entry(2, @sha_b, 1), adapter)
    assert MergeQueue.backoff_ms(1, 30_000) == 1_000
    assert MergeQueue.backoff_ms(10, 30_000) == 30_000
  end

  test "coordinator is disabled without provider calls and deduplicates repeated polls" do
    owner = self()
    one = entry(2, @sha_b, 1)

    {:ok, disabled} =
      MergeQueue.start_link(
        name: nil,
        enabled: false,
        loader: fn -> flunk("disabled queue must not load") end
      )

    MergeQueue.poll(disabled)
    assert %{queues: %{}} = MergeQueue.status(disabled)

    {:ok, enabled} =
      MergeQueue.start_link(
        name: nil,
        enabled: true,
        loader: fn -> {:ok, [one]} end,
        executor: fn action ->
          send(owner, {:action, action})
          {:merged, %{}}
        end,
        interval_ms: 60_000,
        initial_delay: 60_000
      )

    MergeQueue.poll(enabled)
    assert_receive {:action, {:advance, %{pr_number: 2}}}
    MergeQueue.poll(enabled)
    refute_receive {:action, _}
  end

  test "durable loader removal lets an independent successor advance on the next poll" do
    owner = self()
    first = entry(2, @sha_b, 1)
    second = entry(3, @sha_a, 2)
    {:ok, loads} = Agent.start_link(fn -> 0 end)

    loader = fn ->
      call = Agent.get_and_update(loads, &{&1, &1 + 1})
      if call == 0, do: {:ok, [first, second]}, else: {:ok, [second]}
    end

    {:ok, queue} =
      MergeQueue.start_link(
        name: nil,
        enabled: true,
        loader: loader,
        executor: fn {:advance, item} ->
          send(owner, {:advanced, item.pr_number})
          {:update_required, :merge_conflict}
        end,
        initial_delay: 60_000
      )

    MergeQueue.poll(queue)
    assert_receive {:advanced, 2}
    MergeQueue.poll(queue)
    assert_receive {:advanced, 3}
  end

  test "retry outcomes increase a bounded retry delay without consuming the generation" do
    one = entry(2, @sha_b, 1)

    {:ok, queue} =
      MergeQueue.start_link(
        name: nil,
        enabled: true,
        loader: fn -> {:ok, [one]} end,
        executor: fn _action -> {:retry, :rate_limited} end,
        max_retry_backoff_ms: 5_000,
        initial_delay: 60_000
      )

    MergeQueue.poll(queue)
    assert %{retry_attempt: 1, next_delay: 1_000} = MergeQueue.status(queue)
    MergeQueue.poll(queue)
    assert %{retry_attempt: 2, next_delay: 2_000} = MergeQueue.status(queue)
    MergeQueue.poll(queue)
    MergeQueue.poll(queue)
    assert %{retry_attempt: 4, next_delay: 5_000} = MergeQueue.status(queue)
  end

  test "loader failures use bounded backoff and expose the reason" do
    {:ok, queue} =
      MergeQueue.start_link(
        name: nil,
        enabled: true,
        loader: fn -> {:error, :rate_limited} end,
        max_retry_backoff_ms: 5_000,
        initial_delay: 60_000
      )

    MergeQueue.poll(queue)
    assert %{last_error: :rate_limited, retry_attempt: 1, next_delay: 1_000} = MergeQueue.status(queue)
  end

  test "default start_link delegates through the registered server name" do
    assert {:error, {:already_started, _pid}} = MergeQueue.start_link()
  end

  defp entry(number, sha, sequence, branch \\ "main", dependencies \\ []) do
    {:ok, entry} =
      State.new_entry(%{
        "repository" => "octo/repo",
        "target_branch" => branch,
        "pr_number" => number,
        "source_head_sha" => sha,
        "admission_sequence" => sequence,
        "dependencies" => dependencies
      })

    entry
  end
end
