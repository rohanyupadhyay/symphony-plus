defmodule SymphonyElixir.GitHub.MergeQueueConfigTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.Config.Schema

  test "merge queue defaults disabled and validates polling and retry bounds" do
    assert {:ok, defaults} = Schema.parse(%{})
    refute defaults.merge_queue.enabled
    assert defaults.merge_queue.poll_interval_ms == 30_000

    assert {:ok, enabled} =
             Schema.parse(%{
               "merge_queue" => %{
                 "enabled" => true,
                 "poll_interval_ms" => 5_000,
                 "max_retry_backoff_ms" => 60_000
               }
             })

    assert enabled.merge_queue.enabled

    assert {:error, {:invalid_workflow_config, message}} =
             Schema.parse(%{"merge_queue" => %{"poll_interval_ms" => 0}})

    assert message =~ "poll_interval_ms"
  end
end
