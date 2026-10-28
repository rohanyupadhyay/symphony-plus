defmodule SymphonyPlus.ProjectQueueOwnershipTest do
  use ExUnit.Case, async: true
  alias SymphonyPlus.Config.Schema
  alias SymphonyPlus.GitHub.MergeQueue

  test "a busy queue fails closed for idle queries and retains its owner" do
    queue = start_supervised!({MergeQueue, name: :documentation_queue_owner, enabled: false})
    result = MergeQueue.start_link(name: :documentation_queue_owner, enabled: false)
    assert {:error, {:already_started, ^queue}} = result
    :sys.suspend(queue)
    refute MergeQueue.idle?(queue)
    :sys.resume(queue)
    assert MergeQueue.idle?(queue)
  end

  test "different projects cannot concurrently own the same repository queue" do
    repo = "fixture/queue-#{System.unique_integer([:positive])}"
    {:ok, first} = MergeQueue.start_link(name: nil, project_context: context(repo))
    on_exit(fn -> if Process.alive?(first), do: GenServer.stop(first) end)
    result = MergeQueue.start_link(name: nil, project_context: context(String.upcase(repo)))

    if match?({:ok, _}, result) do
      {:ok, second} = result
      on_exit(fn -> if Process.alive?(second), do: GenServer.stop(second) end)
    end

    assert {:error, {:queue_authority_conflict, ^repo}} = result
    assert MergeQueue.idle?(first)
  end

  defp context(repo) do
    {:ok, settings} = Schema.parse(%{"tracker" => %{"kind" => "memory"}})
    %{settings: %{settings | tracker: %{settings.tracker | kind: "github", provider: %{"repo" => repo}}}}
  end
end
