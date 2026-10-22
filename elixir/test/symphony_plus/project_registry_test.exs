defmodule SymphonyPlus.ProjectRegistryTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.ProjectRegistry

  setup do
    root = Path.join(System.tmp_dir!(), "registry-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    registry_path = Path.join(root, "projects.json")
    workflow = Path.join(root, "WORKFLOW.md")
    File.write!(workflow, "---\ntracker:\n  kind: memory\nworkspace:\n  root: tmp/workspaces\n---\nPrompt\n")
    name = String.to_atom("registry_#{System.unique_integer([:positive])}")
    start_supervised!({ProjectRegistry, name: name, path: registry_path, runtime_supervisor: nil})
    on_exit(fn -> File.rm_rf(root) end)
    %{server: name, registry_path: registry_path, workflow: workflow}
  end

  test "persists minimal versioned records and makes duplicate adds idempotent", ctx do
    assert {:ok, registration, :created} = ProjectRegistry.add(ctx.workflow, ctx.server)
    assert {:ok, ^registration, :existing} = ProjectRegistry.add(ctx.workflow, ctx.server)
    assert [^registration] = ProjectRegistry.list(ctx.server)

    decoded = ctx.registry_path |> File.read!() |> Jason.decode!()
    assert decoded["version"] == 1
    assert decoded["projects"] == [%{"id" => registration.id, "workflow_path" => registration.workflow_path}]
    refute File.read!(ctx.registry_path) =~ "Prompt"
  end

  test "removal is idempotent and durable", ctx do
    {:ok, registration, :created} = ProjectRegistry.add(ctx.workflow, ctx.server)
    assert :ok = ProjectRegistry.remove(registration.id, ctx.server)
    assert :ok = ProjectRegistry.remove(registration.id, ctx.server)
    assert [] = ProjectRegistry.list(ctx.server)
  end

  test "canonicalizes a workflow symlink and rejects overlapping workspace roots", ctx do
    shared_workspace = Path.join(Path.dirname(ctx.workflow), "shared-workspaces")
    File.write!(ctx.workflow, "---\ntracker:\n  kind: memory\nworkspace:\n  root: #{shared_workspace}\n---\nPrompt\n")
    symlink = Path.join(Path.dirname(ctx.workflow), "LINK.md")
    File.ln_s!(ctx.workflow, symlink)
    assert {:ok, registration, :created} = ProjectRegistry.add(symlink, ctx.server)
    assert registration.workflow_path == ctx.workflow

    other_root = Path.join(Path.dirname(ctx.workflow), "other")
    File.mkdir_p!(other_root)
    other = Path.join(other_root, "WORKFLOW.md")
    File.write!(other, File.read!(ctx.workflow))
    assert {:error, :workspace_conflict} = ProjectRegistry.add(other, ctx.server)
  end

  test "a failed write preserves the last-good in-memory state", ctx do
    {:ok, registration, :created} = ProjectRegistry.add(ctx.workflow, ctx.server)
    other = Path.join(Path.dirname(ctx.workflow), "OTHER.md")
    File.write!(other, File.read!(ctx.workflow))
    File.chmod!(Path.dirname(ctx.registry_path), 0o500)
    result = ProjectRegistry.add(other, ctx.server)

    File.chmod!(Path.dirname(ctx.registry_path), 0o700)
    if match?({:error, _}, result), do: assert(ProjectRegistry.list(ctx.server) == [registration])
  end
end
