defmodule SymphonyPlus.AgentReviewHandoffTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.{AgentRunner, Config}
  alias SymphonyPlus.Config.Schema
  alias SymphonyPlus.Tracker.Issue

  test "automatic review handoff ends the author invocation before continuing on its thread" do
    with_context(fn ->
      author = issue(nil, nil)
      review = issue(%{"kind" => "automatic_review", "head_sha" => String.duplicate("a", 40)}, "author-thread")
      assert {:done, ^review} = AgentRunner.continue_with_issue_for_test(author, fn _ -> {:ok, [review]} end)
    end)
  end

  test "unchanged review generation can continue but a repaired source needs a new invocation" do
    with_context(fn ->
      first = issue(%{"kind" => "automatic_review", "head_sha" => String.duplicate("a", 40)}, "author-thread")
      assert {:continue, ^first} = AgentRunner.continue_with_issue_for_test(first, fn _ -> {:ok, [first]} end)
      repaired = issue(%{"kind" => "automatic_review", "head_sha" => String.duplicate("b", 40)}, "reviewer-thread")
      assert {:done, ^repaired} = AgentRunner.continue_with_issue_for_test(first, fn _ -> {:ok, [repaired]} end)
    end)
  end

  defp with_context(fun) do
    {:ok, settings} = Schema.parse(%{"tracker" => %{"kind" => "memory", "active_states" => ["open"], "terminal_states" => ["closed"]}})
    Config.with_project_context(%{settings: settings}, fun)
  end

  defp issue(trigger, author) do
    %Issue{
      id: "1",
      identifier: "GH-1",
      title: "Review",
      state: "open",
      dispatchable: true,
      native_ref: %{"workflow_control" => %{"trigger" => trigger, "checkpoint" => %{"documentation_review" => %{"author_thread_id" => author}}}}
    }
  end
end
