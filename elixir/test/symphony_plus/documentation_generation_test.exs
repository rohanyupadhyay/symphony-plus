defmodule SymphonyPlus.DocumentationGenerationTest do
  use ExUnit.Case, async: false
  alias Mix.Tasks.Docs.{Check, Generate}
  alias SymphonyPlus.Documentation
  @repo_root Path.expand("../../..", __DIR__)

  test "reference comes from raw schema defaults and parser options, without environment expansion" do
    {:ok, rendered} = Documentation.render(@repo_root)
    assert rendered =~ "codex.stall_timeout_ms"
    assert rendered =~ "300000"
    assert rendered =~ "--service-url"
    assert rendered =~ "--i-understand-that-this-will-be-running-without-the-usual-guardrails"
    assert rendered =~ "| Erlang (mise) | `28` |"
    assert rendered =~ "| Elixir (mise) | `1.19.5-otp-28` |"
    assert rendered =~ "| Project version | `#{Mix.Project.config()[:version]}` |"
    assert rendered =~ "`linux_arm64`, `linux_x86_64`, `macos_arm64`, `macos_x86_64`"
    assert {:ok, ^rendered} = Documentation.render(@repo_root)
    assert :ok = Documentation.check(@repo_root)

    File.cd!(Path.join(@repo_root, "elixir"), fn ->
      assert :ok = Check.run([])
    end)
  end

  test "pinned metadata changes rendered facts and never expands host secrets" do
    root = fixture_root("docs-metadata")
    File.cp!(Path.join(@repo_root, "elixir/mise.toml"), Path.join(root, "elixir/mise.toml"))
    original = render!(root)
    File.write!(Path.join(root, "elixir/mise.toml"), "[tools]\nerlang = \"29\"\nelixir = \"1.20.0-otp-29\"\n")
    updated = render!(root)
    assert updated =~ "| Erlang (mise) | `29` |"
    refute updated == original

    config = Keyword.put(Mix.Project.config(), :version, "9.9.9")
    {:ok, changed_version} = Documentation.render(root, config)
    assert changed_version =~ "| Project version | `9.9.9` |"
    refute changed_version == updated

    releases = Keyword.fetch!(config, :releases)
    release = Keyword.fetch!(releases, :symphony_plus)
    burrito = Keyword.fetch!(release, :burrito)
    changed_targets = Keyword.put(burrito, :targets, linux_x86_64: [os: :linux, cpu: :x86_64])
    changed_release = Keyword.put(release, :burrito, changed_targets)
    changed_config = Keyword.put(config, :releases, Keyword.put(releases, :symphony_plus, changed_release))
    {:ok, one_target} = Documentation.render(root, changed_config)
    assert one_target =~ "| Burrito targets | `linux_x86_64` |"
    refute one_target =~ "`macos_arm64`"

    System.put_env("SYMPHONY_PLUS_DOCS_HOST_SECRET", "secret-sentinel")
    on_exit(fn -> System.delete_env("SYMPHONY_PLUS_DOCS_HOST_SECRET") end)
    assert {:ok, ^updated} = Documentation.render(root)
    refute updated =~ "secret-sentinel"
    refute updated =~ System.user_home!()
  end

  test "missing pinned versions and missing release metadata are reported" do
    root = fixture_root("docs-invalid-metadata")
    assert {:error, :invalid_pinned_tool_versions} = Documentation.render(root)
    File.write!(Path.join(root, "elixir/mise.toml"), "[tools]\nerlang = \"28\"\n")
    assert {:error, :invalid_pinned_tool_versions} = Documentation.render(root)
    File.cp!(Path.join(@repo_root, "elixir/mise.toml"), Path.join(root, "elixir/mise.toml"))
    assert {:error, :invalid_release_metadata} = Documentation.render(root, version: "1.0.0")
  end

  test "check is read-only and detects missing and stale reference in a disposable root" do
    root = fixture_root("docs-generation")
    File.cp!(Path.join(@repo_root, "elixir/mise.toml"), Path.join(root, "elixir/mise.toml"))
    assert {:error, findings} = Documentation.check(root)
    assert Enum.any?(findings, &(&1.code == :stale_generated_reference))
    File.mkdir_p!(Path.join(root, "elixir/docs"))
    path = Path.join(root, "elixir/docs/configuration-reference.md")
    File.write!(path, "stale\n")
    assert {:error, _} = Documentation.check(root)
    assert File.read!(path) == "stale\n"
    File.write!(path, render!(root))
    assert {:error, findings} = Documentation.check(root)
    refute Enum.any?(findings, &(&1.code == :stale_generated_reference))
  end

  test "check rejects broken links and invalid documented workflow configuration" do
    root = fixture_root("docs-links")
    File.mkdir_p!(Path.join(root, ".symphony-plus"))
    File.write!(Path.join(root, "elixir/README.md"), "[missing](./missing.md)\n")

    File.write!(
      Path.join(root, ".symphony-plus/WORKFLOW.md"),
      "---\ntracker:\n  kind: github\n  provider:\n    repo: OWNER/REPOSITORY\n    auth: {kind: github_app}\n    bootstrap_clone: false\n---\n"
    )

    assert {:error, findings} = Documentation.check(root)
    assert Enum.any?(findings, &(&1.code == :missing_local_reference))
    assert Enum.any?(findings, &(&1.code == :invalid_documented_workflow))
  end

  test "Mix generation writes deliberately and checking rejects stale content without repair" do
    root = fixture_root("docs-tasks")
    File.mkdir_p!(Path.join(root, "elixir/docs"))
    File.cp!(Path.join(@repo_root, "elixir/mise.toml"), Path.join(root, "elixir/mise.toml"))

    File.cd!(Path.join(root, "elixir"), fn ->
      Generate.run([])
      assert File.read!("docs/configuration-reference.md") == render!(root)
      File.write!("docs/configuration-reference.md", "stale")
      assert_raise Mix.Error, ~r/Run mix docs.generate/, fn -> Check.run([]) end
      assert File.read!("docs/configuration-reference.md") == "stale"
    end)
  end

  test "generation fails clearly when authoritative tool metadata is unavailable" do
    root = fixture_root("docs-missing-metadata")

    File.cd!(Path.join(root, "elixir"), fn ->
      assert_raise Mix.Error, ~r/Cannot generate documentation/, fn -> Generate.run([]) end
      refute File.exists?("docs/configuration-reference.md")
    end)
  end

  defp fixture_root(prefix) do
    root = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "elixir"))
    on_exit(fn -> File.rm_rf!(root) end)
    root
  end

  defp render!(root) do
    {:ok, rendered} = Documentation.render(root)
    rendered
  end
end
