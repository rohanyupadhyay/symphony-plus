defmodule SymphonyPlus.ConfigurationReferenceContractTest do
  use ExUnit.Case, async: true
  alias SymphonyPlus.Config.Schema

  test "workspace fallback is resolved at runtime rather than embedded into compiled metadata" do
    assert %Schema.Workspace{}.root == nil
    assert {:ok, settings} = Schema.parse(%{"tracker" => %{"kind" => "memory"}})
    assert settings.workspace.root == Path.join(System.tmp_dir!(), "symphony-plus-workspaces")
  end

  test "documented server ports validate zero and positive values and reject negative ports" do
    for port <- [0, 4001] do
      assert {:ok, settings} = Schema.parse(%{"server" => %{"port" => port, "host" => "127.0.0.1"}})
      assert settings.server.port == port
    end

    assert {:error, _reason} = Schema.parse(%{"server" => %{"port" => -1}})
  end
end
