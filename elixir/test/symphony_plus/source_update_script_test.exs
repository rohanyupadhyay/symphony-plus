defmodule SymphonyPlus.SourceUpdateScriptTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../scripts/apply-source-update", __DIR__)

  test "promotes the prepared executable and launches from the Elixir directory" do
    %{base: base, install: install, prepared: prepared, revision: revision} = repository_fixture()
    marker = Path.join(base, "running-version")
    assert {_, 0} = System.cmd(@script, [install, prepared, revision, "99999999", "./bin/symphony-plus > #{marker}"], stderr_to_stdout: true)
    eventually(fn -> File.exists?(marker) and File.read!(marker) == "new\n" end)
    assert File.read!(Path.join(install, "elixir/bin/symphony-plus")) =~ "new"
  end

  test "failed candidate launch restores the prior executable with original arguments" do
    %{base: base, install: install, prepared: prepared, revision: revision} = repository_fixture()
    marker = Path.join(base, "prior-restarted")
    original_cwd = Path.join(base, "operator")
    File.mkdir_p!(original_cwd)
    args = Path.join(base, "restart.args")
    File.write!(args, "--port\0" <> "4011\0")
    File.write!(Path.join(install, "elixir/bin/symphony-plus"), "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{marker}\npwd > #{marker}.cwd\n")
    File.write!(Path.join(prepared, "elixir/bin/symphony-plus"), "#!/bin/sh\nexit 1\n")
    assert {_, 0} = System.cmd(@script, [install, prepared, revision, "99999999", "./bin/symphony-plus", args], env: [{"SYMPHONY_PLUS_RESTART_CWD", original_cwd}])
    eventually(fn -> File.exists?(marker <> ".cwd") end)
    assert File.read!(marker) == "--port\n4011\n"
    assert String.trim(File.read!(marker <> ".cwd")) == original_cwd
    assert File.read!(Path.join(install, ".git/symphony-plus-update.outcome")) =~ "blocked: launcher failed"
  end

  test "a delayed startup failure rolls back instead of being reported as restarted" do
    %{base: base, install: install, prepared: prepared, revision: revision} = repository_fixture()
    marker = Path.join(base, "delayed-prior")
    File.write!(Path.join(install, "elixir/bin/symphony-plus"), "#!/bin/sh\necho recovered > #{marker}\n")
    File.write!(Path.join(prepared, "elixir/bin/symphony-plus"), "#!/bin/sh\nsleep 2.2\nexit 1\n")
    assert {_, 0} = System.cmd(@script, [install, prepared, revision, "99999999", "./bin/symphony-plus"])
    eventually(fn -> File.exists?(marker) end)
    assert File.read!(Path.join(install, ".git/symphony-plus-update.outcome")) =~ "blocked: launcher failed"
  end

  test "helper locks, waits for an exited pid, fast-forwards exactly, and launches" do
    %{base: base, install: install, prepared: prepared, revision: revision} = repository_fixture()
    marker = Path.join(base, "launched")

    assert {_, 0} =
             System.cmd(@script, [install, prepared, revision, "99999999", "touch #{marker}; exec ./bin/symphony-plus"], stderr_to_stdout: true)

    eventually(fn -> File.exists?(marker) and File.read!(Path.join(install, ".git/symphony-plus-update.outcome")) =~ "restarted:" end)
    assert git!(install, ["rev-parse", "HEAD"]) == revision
    assert File.read!(Path.join(install, ".git/symphony-plus-update.outcome")) =~ "restarted:#{revision}"
  end

  test "held installation lock records a bounded blocked outcome" do
    %{install: install, prepared: prepared, revision: revision} = repository_fixture()
    File.mkdir_p!(Path.join(install, ".git/symphony-plus-update.lock"))

    assert {_, 1} = System.cmd(@script, [install, prepared, revision, "99999999", "true"])
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
    File.write!(Path.join(seed, ".gitignore"), "/elixir/bin/\n/elixir/_build/\n")
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

    for {path, label} <- [{install, "old"}, {prepared, "new"}] do
      File.mkdir_p!(Path.join(path, "elixir/bin"))
      executable = Path.join(path, "elixir/bin/symphony-plus")

      File.write!(
        executable,
        "#!/bin/sh\nprintf '%s\\n' #{label}\nif test -n \"${SYMPHONY_PLUS_UPDATE_READY_FILE:-}\"; then printf '%s\\n' \"$$\" > \"$SYMPHONY_PLUS_UPDATE_READY_FILE\"; fi\ntrap 'exit 0' TERM\nwhile :; do sleep 1; done\n"
      )

      File.chmod!(executable, 0o755)
    end

    on_exit(fn ->
      stop_ready_process(install)
      File.rm_rf!(base)
    end)

    %{base: base, install: install, prepared: prepared, revision: revision}
  end

  defp stop_ready_process(install) do
    ready = Path.join(install, ".git/symphony-plus-update.ready")
    if File.exists?(ready), do: stop_test_pid(String.trim(File.read!(ready)))
  end

  defp stop_test_pid(pid) do
    if Regex.match?(~r/\A[0-9]+\z/, pid), do: System.cmd("kill", ["-TERM", pid], stderr_to_stdout: true)
  end

  defp git!(cwd, args) do
    case System.cmd("git", args, cd: cwd, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("git #{inspect(args)} failed (#{status}): #{output}")
    end
  end

  # The helper allows ten seconds for readiness, in addition to promotion and rollback.
  defp eventually(fun, timeout_ms \\ 15_000) do
    await(fun, System.monotonic_time(:millisecond) + timeout_ms)
  end

  defp await(fun, deadline) do
    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        flunk("condition did not become true before the handoff deadline")

      true ->
        Process.sleep(20)
        await(fun, deadline)
    end
  end
end
