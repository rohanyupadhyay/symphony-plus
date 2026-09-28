defmodule SymphonyElixir.GitHub.AppRuntimeTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.GitHub.AppProfile

  setup do
    root = Path.join(System.tmp_dir!(), "symphony-app-runtime-#{System.unique_integer([:positive])}")
    key_path = Path.join(root, "invalid-private-key.pem")
    File.mkdir_p!(root)
    File.write!(key_path, "invalid test key")
    File.chmod!(key_path, 0o600)

    on_exit(fn ->
      {:ok, _apps} = Application.ensure_all_started(:req)
      File.rm_rf(root)
    end)

    %{key_path: key_path}
  end

  test "standalone profile verification starts the Req HTTP runtime", %{key_path: key_path} do
    assert :ok = Application.stop(:req)
    refute Process.whereis(Req.FinchSupervisor)

    profile = %{
      app_id: 123,
      installation_id: 456,
      private_key_path: key_path,
      bot_login: ""
    }

    assert {:error, :invalid_github_app_private_key} =
             AppProfile.verify(profile, "octo/repo")

    assert is_pid(Process.whereis(Req.FinchSupervisor))
  end
end
