defmodule SymphonyPlus.GitHub.AppProfileTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.GitHub.AppProfile

  setup do
    root = Path.join(System.tmp_dir!(), "symphony-plus-app-profile-#{System.unique_integer([:positive])}")
    source_key = Path.join(root, "downloaded.pem")
    File.mkdir_p!(root)
    File.write!(source_key, "private-key")
    File.chmod!(source_key, 0o600)
    on_exit(fn -> File.rm_rf(root) end)
    %{root: root, source_key: source_key}
  end

  test "registration URL requests only the documented write permissions and no webhook" do
    uri = AppProfile.registration_url("octo/repo", "Rohan Symphony Plus") |> URI.parse()
    query = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "github.com"
    assert uri.path == "/settings/apps/new"
    assert query["name"] == "Rohan Symphony Plus"
    assert query["public"] == "false"
    assert query["webhook_active"] == "false"
    assert query["contents"] == "write"
    assert query["issues"] == "write"
    assert query["pull_requests"] == "write"
    assert query["workflows"] == "write"
    assert query["checks"] == "read"
    assert query["statuses"] == "read"
    refute Map.has_key?(query, "administration")
  end

  test "verification checks private-review read endpoints and reports permission denial", context do
    profile = %{app_id: 1, installation_id: 2, private_key_path: context.source_key, bot_login: "app[bot]"}
    identity = %{id: 9, login: "app[bot]", slug: "app"}

    client = fn "GET", path, _, _, _ ->
      case path do
        "/repos/octo/repo" -> {:ok, %{status: 200, body: %{"default_branch" => "main"}}}
        "/repos/octo/repo/commits/main/check-runs" -> {:ok, %{status: 403, body: %{}}}
      end
    end

    assert {:error, {:github_app_review_permission_status, "checks", 403}} =
             AppProfile.verify(profile, "octo/repo", identity_fun: fn _ -> {:ok, identity} end, github_client: client)

    client = fn "GET", path, _, _, _ ->
      body = if path == "/repos/octo/repo", do: %{"default_branch" => "main"}, else: %{}
      {:ok, %{status: 200, body: body}}
    end

    assert {:ok, ^identity} = AppProfile.verify(profile, "octo/repo", identity_fun: fn _ -> {:ok, identity} end, github_client: client)
  end

  test "creates an atomic private profile and loads launcher environment", context do
    config_root = Path.join(context.root, "config")
    parent = self()

    verify_fun = fn profile, repo ->
      send(parent, {:verified, profile, repo})
      {:ok, %{login: "verity-symphony-plus[bot]"}}
    end

    assert {:ok, profile} =
             AppProfile.create(
               "octo/repo",
               "default",
               123,
               456,
               context.source_key,
               config_root: config_root,
               verify_fun: verify_fun
             )

    assert_received {:verified, verified_profile, "octo/repo"}
    assert verified_profile.app_id == 123
    assert profile.bot_login == "verity-symphony-plus[bot]"
    assert {:ok, loaded} = AppProfile.load("default", config_root: config_root)
    assert loaded == profile
    assert File.read!(profile.private_key_path) == "private-key"
    assert File.stat!(Path.dirname(profile.private_key_path)).mode |> Bitwise.band(0o777) == 0o700
    assert File.stat!(profile.private_key_path).mode |> Bitwise.band(0o777) == 0o600

    assert {:ok, environment} = AppProfile.environment("default", config_root: config_root)

    assert environment == [
             {"GITHUB_APP_ID", "123"},
             {"GITHUB_APP_INSTALLATION_ID", "456"},
             {"GITHUB_APP_PRIVATE_KEY_PATH", profile.private_key_path}
           ]
  end

  test "does not leave a profile when verification fails", context do
    config_root = Path.join(context.root, "config")

    assert {:error, :installation_not_found} =
             AppProfile.create(
               "octo/repo",
               "default",
               123,
               456,
               context.source_key,
               config_root: config_root,
               verify_fun: fn _profile, _repo -> {:error, :installation_not_found} end
             )

    refute File.exists?(Path.join([config_root, "symphony-plus", "github-apps", "default"]))
  end

  test "removes staged key material when verification exits", context do
    config_root = Path.join(context.root, "config")

    result =
      try do
        AppProfile.create(
          "octo/repo",
          "default",
          123,
          456,
          context.source_key,
          config_root: config_root,
          verify_fun: fn _profile, _repo -> exit(:http_runtime_missing) end
        )
      catch
        :exit, reason -> {:uncaught_exit, reason}
      end

    assert result ==
             {:error, {:github_app_profile_verification_failed, :http_runtime_missing}}

    profiles_root = Path.join([config_root, "symphony-plus", "github-apps"])
    assert File.ls!(profiles_root) == []
  end

  test "rejects invalid profile names, repositories, IDs, keys, and overwrite attempts", context do
    opts = [
      config_root: Path.join(context.root, "config"),
      verify_fun: fn _profile, _repo -> {:ok, %{login: "app[bot]"}} end
    ]

    assert {:error, :invalid_github_app_profile_name} =
             AppProfile.create("octo/repo", "../escape", 1, 2, context.source_key, opts)

    assert {:error, :invalid_github_repo} =
             AppProfile.create("not-a-repo", "default", 1, 2, context.source_key, opts)

    assert {:error, :invalid_github_app_id} =
             AppProfile.create("octo/repo", "default", 0, 2, context.source_key, opts)

    assert {:error, :invalid_github_app_private_key_path} =
             AppProfile.create("octo/repo", "default", 1, 2, "/missing/key.pem", opts)

    assert {:ok, _profile} =
             AppProfile.create("octo/repo", "default", 1, 2, context.source_key, opts)

    assert {:error, :github_app_profile_exists} =
             AppProfile.create("octo/repo", "default", 1, 2, context.source_key, opts)
  end
end
