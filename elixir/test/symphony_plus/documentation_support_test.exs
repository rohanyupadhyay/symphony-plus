defmodule SymphonyPlus.DocumentationSupportTest do
  use ExUnit.Case, async: false
  alias SymphonyPlus.DocumentationSupport, as: Docs
  @moduletag :documentation

  test "extracts exact marked fence bytes and rejects missing duplicate or malformed scenarios" do
    Docs.with_fixture(fn f ->
      path = Path.join(f.root, "examples.md")
      body = "echo \"a b\"\nprintf '%s\\n' done\n"
      fence = "<!-- docs:scenario exact -->\n```bash\n#{body}```\n"
      File.write!(path, fence)
      assert Docs.command_block!(path, "exact") == body
      assert_raise ArgumentError, fn -> Docs.command_block!(path, "missing") end
      File.write!(path, fence <> fence)
      assert_raise ArgumentError, fn -> Docs.command_block!(path, "exact") end
      File.write!(path, "<!-- docs:scenario exact -->\n```text\ntrue\n```\n")
      assert_raise ArgumentError, fn -> Docs.command_block!(path, "exact") end
    end)
  end

  test "preserves command failures and removes host credentials and configuration" do
    System.put_env("SYMPHONY_PLUS_DOCS_HOST_SECRET", "host-sentinel")
    on_exit(fn -> System.delete_env("SYMPHONY_PLUS_DOCS_HOST_SECRET") end)

    Docs.with_fixture(fn f ->
      for _ <- 1..5, do: assert({"", 0} = Docs.run("true", f))
      assert {"failure\n", 23} = Docs.run("echo failure; exit 23", f)

      assert {"clean\n", 0} =
               Docs.run(~s(test -z "${SYMPHONY_PLUS_DOCS_HOST_SECRET:-}" && test ! -e "$HOME/.codex/auth.json" && echo clean), f)
    end)
  end

  test "timeout and assertion failures clean up the whole process group" do
    Docs.with_fixture(fn f ->
      pidfile = Path.join(f.root, "child.pid")
      command = "sleep 300 & echo $! > \"$PIDFILE\"; wait"
      f = Docs.put_env(f, "PIDFILE", pidfile)

      assert_raise RuntimeError, ~r/readiness timeout/, fn ->
        Docs.with_service(command, f, fn _ -> false end, fn _ -> :unreachable end, timeout: 100)
      end

      assert_dead(pidfile)
      File.rm!(pidfile)

      assert_raise ExUnit.AssertionError, fn ->
        Docs.with_service(command, f, fn _ -> File.exists?(pidfile) end, fn _ -> flunk("fixture failure") end)
      end

      assert_dead(pidfile)
    end)
  end

  defp assert_dead(path) do
    pid = path |> File.read!() |> String.trim()
    assert {_output, status} = System.cmd("kill", ["-0", pid], stderr_to_stdout: true)
    assert status != 0
  end
end
