defmodule SymphonyPlus.SourceUpdateScriptTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../scripts/apply-source-update", __DIR__)

  test "helper locks, waits for an exited pid, fast-forwards exactly, and launches" do
    %{base: base, install: install, prepared: prepared, revision: revision} = repository_fixture()
    marker = Path.join(base, "launched")

    assert {_, 0} =
             System.cmd(@script, [install, prepared, revision, "99999999", "touch #{marker}"], stderr_to_stdout: true)

    eventually(fn -> File.exists?(marker) end)
    assert git!(install, ["rev-parse", "HEAD"]) == revision
    assert File.read!(Path.join(install, ".git/symphony-plus-update.outcome")) =~ "restarted:#{revision}"
  end

  test "held installation lock records a bounded blocked outcome" do
    %{install: install, prepared: prepared, revision: revision} = repository_fixture()
    File.mkdir_p!(Path.join(install, ".git/symphony-plus-update.lock"))

    assert {_, 0} = System.cmd(@script, [install, prepared, revision, "99999999", "true"])
    eventually(fn -> File.exists?(Path.join(install, ".git/symphony-plus-update.outcome")) end)
    assert File.read!(Path.join(install, ".git/symphony-plus-update.outcome")) == "blocked: update lock is held\n"
  end

  defp repository_fixture do
    base = Path.join(System.tmp_dir!(), "source-update-script-#{System.unique_integer([:positive])}")
    remote = Path.join(base, "remote.git")
    seed = Path.join(base, "seed")
    install = Path.join(base, "install")
    prepared = Path.join(base, "prepared")
    File.mkdir_p!(base)
    git!(base, ["init", "--bare", remote])
    git!(base, ["init", "-b", "main", seed])
    git!(seed, ["config", "user.email", "test@example.com"])
    git!(seed, ["config", "user.name", "Test"])
    File.write!(Path.join(seed, "VERSION"), "one\n")
    git!(seed, ["add", "."])
    git!(seed, ["commit", "-m", "one"])
    git!(seed, ["remote", "add", "origin", remote])
    git!(seed, ["push", "-u", "origin", "main"])
    git!(base, ["--git-dir", remote, "symbolic-ref", "HEAD", "refs/heads/main"])
    git!(base, ["clone", remote, install])
    File.write!(Path.join(seed, "VERSION"), "two\n")
    git!(seed, ["commit", "-am", "two"])
    git!(seed, ["push"])
    revision = git!(seed, ["rev-parse", "HEAD"])
    git!(install, ["fetch", "origin"])
    git!(base, ["clone", remote, prepared])
    on_exit(fn -> File.rm_rf!(base) end)
    %{base: base, install: install, prepared: prepared, revision: revision}
  end

  defp git!(cwd, args) do
    case System.cmd("git", args, cd: cwd, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("git #{inspect(args)} failed (#{status}): #{output}")
    end
  end

  defp eventually(fun, attempts \\ 100)

  defp eventually(fun, attempts) when attempts > 0 do
    if fun.(),
      do: :ok,
      else:
        (
          Process.sleep(20)
          eventually(fun, attempts - 1)
        )
  end

  defp eventually(_fun, 0), do: flunk("condition did not become true")
end
