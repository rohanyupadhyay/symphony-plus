defmodule SymphonyElixir.GitHub.ClientTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.GitHub.Client

  @sha String.duplicate("a", 40)

  test "conditional mutations carry exact head evidence" do
    owner = self()

    request = fn method, path, params, body, _settings ->
      send(owner, {:request, method, path, params, body})
      {:ok, %{status: 200, body: %{"ok" => true}}}
    end

    opts = [tracker_settings: tracker(), request_fun: request]
    assert {:ok, %{"ok" => true}} = Client.update_branch("octo/repo", 7, @sha, opts)

    assert_receive {:request, "PUT", "/repos/octo/repo/pulls/7/update-branch", %{}, %{"expected_head_sha" => @sha}}

    assert {:ok, %{"ok" => true}} = Client.merge_pull_request("octo/repo", 7, @sha, opts)
    assert_receive {:request, "PUT", "/repos/octo/repo/pulls/7/merge", %{}, %{"sha" => @sha}}
  end

  defp tracker do
    %{provider: %{"repo" => "octo/repo", "token" => "test-token"}}
  end
end
