defmodule SymphonyElixir.QuotaWaitStoreTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.QuotaWaitStore

  setup do
    root = Path.join(System.tmp_dir!(), "quota-wait-store-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)
    %{root: root}
  end

  test "atomically writes and reads an allowlisted version one record", %{root: root} do
    record = valid_record(%{"provider_payload" => %{"token" => "must-not-persist"}})

    assert :ok = QuotaWaitStore.put(root, record)
    assert {:ok, stored} = QuotaWaitStore.fetch(root, "issue-8")
    assert stored == valid_record()
    refute Map.has_key?(stored, "provider_payload")
    assert {:ok, [^stored]} = QuotaWaitStore.list(root)

    store_dir = Path.join([root, ".symphony", "quota-waits"])
    assert [filename] = File.ls!(store_dir)
    assert String.ends_with?(filename, ".json")
    refute String.contains?(filename, "..")
  end

  test "rejects invalid fields, states, versions, timestamps, and workspace keys", %{root: root} do
    for record <- [
          valid_record(%{"version" => 2}),
          valid_record(%{"status" => "retrying"}),
          valid_record(%{"workspace_key" => "../escape"}),
          valid_record(%{"next_recheck_at" => "not-a-time"}),
          Map.delete(valid_record(), "issue_identifier")
        ] do
      assert {:error, {:invalid_quota_wait, _reason}} = QuotaWaitStore.put(root, record)
    end

    assert {:error, :invalid_issue_id} = QuotaWaitStore.fetch(root, "../escape")
    assert {:error, :invalid_workspace_root} = QuotaWaitStore.put(123, valid_record())
  end

  test "fails closed for corrupt records and unknown versions", %{root: root} do
    assert :ok = QuotaWaitStore.put(root, valid_record())
    [path] = Path.wildcard(Path.join([root, ".symphony", "quota-waits", "*.json"]))

    File.write!(path, "not json")
    assert {:error, {:corrupt_quota_wait, _path, _reason}} = QuotaWaitStore.fetch(root, "issue-8")

    File.write!(path, Jason.encode!(valid_record(%{"version" => 99})))

    assert {:error, {:invalid_quota_wait, :unknown_version}} =
             QuotaWaitStore.fetch(root, "issue-8")
  end

  test "deletes an issue-scoped record idempotently", %{root: root} do
    assert :ok = QuotaWaitStore.put(root, valid_record())
    assert :ok = QuotaWaitStore.delete(root, "issue-8")
    assert :not_found = QuotaWaitStore.fetch(root, "issue-8")
    assert :ok = QuotaWaitStore.delete(root, "issue-8")
  end

  defp valid_record(overrides \\ %{}) do
    Map.merge(
      %{
        "version" => 1,
        "issue_id" => "issue-8",
        "issue_identifier" => "GH-8",
        "harness" => "codex",
        "pool_key" => "codex:account:default",
        "status" => "waiting",
        "renewal_at" => "2026-10-01T01:00:00Z",
        "next_recheck_at" => "2026-10-01T01:00:00Z",
        "workspace_key" => "GH-8",
        "continuation" => %{
          "harness" => "codex",
          "native_id" => "thread-123",
          "issue_id" => "issue-8",
          "workspace_key" => "GH-8"
        },
        "last_outcome" => "quota_exhausted",
        "observed_at" => "2026-10-01T00:00:00Z",
        "updated_at" => "2026-10-01T00:00:00Z"
      },
      overrides
    )
  end
end
