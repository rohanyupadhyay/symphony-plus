defmodule SymphonyPlus.UpdateConfigTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.Config.Schema

  test "updates are disabled by default" do
    assert {:ok, settings} = Schema.parse(%{})
    refute settings.updates.enabled
  end

  test "enabled updates require a safe checkout and commands" do
    assert {:error, {:invalid_workflow_config, message}} =
             Schema.parse(%{"updates" => %{"enabled" => true, "interval_ms" => 0}})

    assert message =~ "interval_ms"
    assert message =~ "installation_root"
  end

  test "commands reject literal credentials" do
    root = Path.join(System.tmp_dir!(), "update-config-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, ".git"))
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:error, {:invalid_workflow_config, message}} =
             Schema.parse(%{
               "updates" => %{
                 "enabled" => true,
                 "installation_root" => root,
                 "prepare_command" => "token=secret make all",
                 "launcher_command" => "./run"
               }
             })

    assert message =~ "literal credentials"
  end

  test "enabled updates accept disjoint roots and reject overlapping workspace roots" do
    root = Path.join(System.tmp_dir!(), "update-roots-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, ".git"))
    on_exit(fn -> File.rm_rf!(root) end)
    update = %{"enabled" => true, "installation_root" => root, "prepare_command" => "true", "launcher_command" => "true"}

    assert {:ok, _settings} = Schema.parse(%{"updates" => update, "workspace" => %{"root" => root <> "-workspaces"}})
    assert {:error, {:invalid_workflow_config, message}} = Schema.parse(%{"updates" => update, "workspace" => %{"root" => root}})
    assert message =~ "must not overlap"
  end
end
