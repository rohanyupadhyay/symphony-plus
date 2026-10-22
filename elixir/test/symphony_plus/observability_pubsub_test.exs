defmodule SymphonyPlus.ObservabilityPubSubTest do
  use SymphonyPlus.TestSupport

  alias SymphonyPlusWeb.ObservabilityPubSub

  test "subscribe and broadcast_update deliver dashboard updates" do
    assert :ok = ObservabilityPubSub.subscribe()
    assert :ok = ObservabilityPubSub.broadcast_update()
    assert_receive :observability_updated
  end

  test "broadcast_update is a no-op when pubsub is unavailable" do
    pubsub_child_id = Phoenix.PubSub.Supervisor

    on_exit(fn ->
      if Process.whereis(SymphonyPlus.PubSub) == nil do
        assert {:ok, _pid} =
                 Supervisor.restart_child(SymphonyPlus.Supervisor, pubsub_child_id)
      end
    end)

    assert is_pid(Process.whereis(SymphonyPlus.PubSub))
    assert :ok = Supervisor.terminate_child(SymphonyPlus.Supervisor, pubsub_child_id)
    refute Process.whereis(SymphonyPlus.PubSub)

    assert :ok = ObservabilityPubSub.broadcast_update()
  end
end
