defmodule SymphonyElixir.GitHub.MergeQueue.StateTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.GitHub.MergeQueue.State

  @sha String.duplicate("a", 40)

  test "normalizes an admission and round-trips it through a checkpoint" do
    attrs = %{
      "repository" => "octo/repo",
      "target_branch" => "main",
      "pr_number" => 12,
      "source_head_sha" => @sha,
      "originating_issue" => 7,
      "admission_sequence" => 22,
      "dependencies" => [4, "#9", 4]
    }

    assert {:ok, entry} = State.new_entry(attrs)
    assert entry.dependencies == [4, 9]
    assert entry.generation == {12, @sha}
    assert {:ok, ^entry} = entry |> State.to_checkpoint() |> State.from_checkpoint()
  end

  test "rejects invalid identities and dependency declarations" do
    assert {:error, :invalid_repository} = State.new_entry(%{"repository" => "elsewhere"})

    assert {:ok, %{dependencies: [12]}} =
             State.new_entry(%{
               "repository" => "octo/repo",
               "target_branch" => "main",
               "pr_number" => 12,
               "source_head_sha" => @sha,
               "admission_sequence" => 1,
               "dependencies" => [12]
             })

    valid = %{
      "repository" => "octo/repo",
      "target_branch" => "main",
      "pr_number" => 12,
      "source_head_sha" => @sha,
      "admission_sequence" => 1
    }

    assert {:error, :invalid_entry} = State.new_entry(nil)
    assert {:error, :invalid_checkpoint} = State.from_checkpoint(%{})
    assert {:error, :invalid_repository} = State.new_entry(%{valid | "repository" => nil})
    assert {:error, :invalid_target_branch} = State.new_entry(%{valid | "target_branch" => nil})
    assert {:error, :invalid_pr_number} = State.new_entry(%{valid | "pr_number" => nil})
    assert {:error, :invalid_sha} = State.new_entry(%{valid | "source_head_sha" => nil})
    assert {:error, :invalid_admission_sequence} = State.new_entry(%{valid | "admission_sequence" => nil})
    assert {:error, :invalid_dependency} = State.new_entry(Map.put(valid, "dependencies", :invalid))
    assert {:error, :invalid_dependency} = State.new_entry(Map.put(valid, "dependencies", ["bad"]))
    assert {:error, :invalid_dependency} = State.new_entry(Map.put(valid, "dependencies", [%{}]))
  end

  test "candidate freshness requires the exact candidate and target revisions" do
    candidate = %State.Candidate{
      source_head_sha: @sha,
      target_sha: String.duplicate("b", 40),
      candidate_sha: String.duplicate("c", 40)
    }

    assert State.fresh?(candidate, candidate.candidate_sha, candidate.target_sha)
    refute State.fresh?(candidate, @sha, candidate.target_sha)
  end
end
