defmodule SymphonyPlus.SourceUpdateTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.SourceUpdate

  setup do
    base = Path.join(System.tmp_dir!(), "source-update-#{System.unique_integer([:positive])}")
    remote = Path.join(base, "remote.git")
    seed = Path.join(base, "seed")
    install = Path.join(base, "install")
    File.mkdir_p!(base)
    git!(base, ["init", "--bare", remote])
    git!(base, ["init", "-b", "main", seed])
    git!(seed, ["config", "user.email", "test@example.com"])
    git!(seed, ["config", "user.name", "Test"])
    File.write!(Path.join(seed, "README"), "one\n")
    git!(seed, ["add", "README"])
    git!(seed, ["commit", "-m", "one"])
    git!(seed, ["remote", "add", "origin", remote])
    git!(seed, ["push", "-u", "origin", "main"])
    git!(base, ["--git-dir", remote, "symbolic-ref", "HEAD", "refs/heads/main"])
    git!(base, ["clone", remote, install])
    on_exit(fn -> File.rm_rf!(base) end)
    %{seed: seed, install: install}
  end

  test "discovers immutable fast-forward candidate and rejects dirt", %{seed: seed, install: install} do
    assert {:ok, :current} = SourceUpdate.discover(install)
    File.write!(Path.join(seed, "README"), "two\n")
    git!(seed, ["commit", "-am", "two"])
    git!(seed, ["push"])
    assert {:ok, %{revision: revision, default_branch: "main"}} = SourceUpdate.discover(install)
    assert byte_size(revision) == 40

    File.write!(Path.join(install, "local"), "dirty")
    assert {:error, :dirty_checkout} = SourceUpdate.discover(install)
  end

  test "prepares candidate in a detached worktree", %{seed: seed, install: install} do
    File.mkdir_p!(Path.join(seed, "elixir"))
    File.write!(Path.join(seed, "elixir/.keep"), "")
    File.write!(Path.join(seed, "README"), "two\n")
    git!(seed, ["add", "."])
    git!(seed, ["commit", "-m", "two"])
    git!(seed, ["push"])
    assert {:ok, candidate} = SourceUpdate.discover(install)
    assert {:ok, path} = SourceUpdate.prepare(install, candidate, "mkdir -p bin && printf '#!/bin/sh\\nexit 0\\n' > bin/symphony-plus && chmod +x bin/symphony-plus")
    assert String.trim(elem(System.cmd("git", ["rev-parse", "HEAD"], cd: path), 0)) == candidate.revision
  end

  test "rejects preparation that does not produce an executable", %{seed: seed, install: install} do
    File.mkdir_p!(Path.join(seed, "elixir"))
    File.write!(Path.join(seed, "elixir/.keep"), "")
    git!(seed, ["add", "."])
    git!(seed, ["commit", "-m", "candidate without executable"])
    git!(seed, ["push"])
    assert {:ok, candidate} = SourceUpdate.discover(install)
    assert {:error, :prepared_executable_missing} = SourceUpdate.prepare(install, candidate, "true")
  end

  test "refuses preparation while the installation preparation lock is held", %{seed: seed, install: install} do
    File.mkdir_p!(Path.join(seed, "elixir"))
    File.write!(Path.join(seed, "elixir/.keep"), "")
    git!(seed, ["add", "."])
    git!(seed, ["commit", "-m", "candidate"])
    git!(seed, ["push"])
    assert {:ok, candidate} = SourceUpdate.discover(install)
    File.mkdir!(Path.join(install, ".git/symphony-plus-prepare.lock"))
    assert {:error, :preparation_locked} = SourceUpdate.prepare(install, candidate, "true")
  end

  defp git!(cwd, args) do
    case System.cmd("git", args, cd: cwd, stderr_to_stdout: true) do
      {output, 0} -> output
      {output, status} -> flunk("git #{inspect(args)} failed (#{status}): #{output}")
    end
  end
end
