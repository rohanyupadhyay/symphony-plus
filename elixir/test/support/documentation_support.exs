defmodule SymphonyPlus.DocumentationSupport do
  @moduledoc false

  def command_block!(path, id) do
    contents = File.read!(path)
    marker = "<!-- docs:scenario #{id} -->"
    pattern = ~r/#{Regex.escape(marker)}\r?\n```bash\r?\n(.*?)^```\r?$/ms

    case {length(:binary.matches(contents, marker)), Regex.scan(pattern, contents, capture: :all_but_first)} do
      {1, [[body]]} -> body
      _ -> raise ArgumentError, "#{path}: scenario #{id}: expected one marker immediately followed by a closed Bash fence"
    end
  end

  def with_fixture(fun) do
    root = Path.join(System.tmp_dir!(), "documentation-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    for dir <- ~w(home cwd data logs workspaces xdg codex), do: File.mkdir_p!(Path.join(root, dir))
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)
    executable = Path.expand("../../bin/symphony-plus", __DIR__)

    fixture = %{
      root: root,
      cwd: Path.join(root, "cwd"),
      port: port,
      env: %{
        "PATH" => Path.dirname(System.find_executable("erl")) <> ":/usr/bin:/bin",
        "HOME" => Path.join(root, "home"),
        "XDG_CONFIG_HOME" => Path.join(root, "xdg"),
        "XDG_DATA_HOME" => Path.join(root, "xdg"),
        "CODEX_HOME" => Path.join(root, "codex"),
        "ERL_FLAGS" => "+S 2:2",
        "LANG" => "C.UTF-8",
        "SYMPHONY_PLUS_BIN" => executable,
        "SYMPHONY_PLUS_DATA_ROOT" => Path.join(root, "data"),
        "SYMPHONY_PLUS_LOGS_ROOT" => Path.join(root, "logs"),
        "SYMPHONY_PLUS_PORT" => to_string(port),
        "SYMPHONY_PLUS_SERVICE_URL" => "http://127.0.0.1:#{port}"
      }
    }

    try do
      fun.(fixture)
    after
      File.rm_rf!(root)
    end
  end

  def put_env(fixture, key, value), do: put_in(fixture.env[key], value)

  def run(command, fixture, opts \\ []) do
    child = start(command, fixture)

    try do
      collect(child, System.monotonic_time(:millisecond) + Keyword.get(opts, :timeout, 15_000), "")
    after
      stop(child)
    end
  end

  def with_service(command, fixture, ready, assertion, opts \\ []) do
    child = start(command, fixture)

    try do
      await_ready(child, fixture, ready, System.monotonic_time(:millisecond) + Keyword.get(opts, :timeout, 15_000), "")
      assertion.(fixture)
    after
      stop(child)
    end
  end

  defp start(command, fixture) do
    group_file = Path.join(fixture.root, "group-#{System.unique_integer([:positive])}.pid")

    args =
      ["-i"] ++
        Enum.map(fixture.env, fn {key, value} -> "#{key}=#{value}" end) ++
        [System.find_executable("setsid"), "--wait", "/bin/bash", "--noprofile", "--norc", "-c", ~s(echo $$ > "$1"; exec /bin/bash --noprofile --norc -c "$2"), "docs", group_file, command]

    port = Port.open({:spawn_executable, System.find_executable("env")}, [:binary, :exit_status, :stderr_to_stdout, args: args, cd: fixture.cwd])

    pid =
      case Port.info(port, :os_pid) do
        {:os_pid, value} -> value
        nil -> nil
      end

    %{port: port, pid: pid, group_file: group_file}
  end

  defp collect(child, deadline, output) do
    receive do
      {port, {:data, bytes}} when port == child.port -> collect(child, deadline, bounded(output <> bytes))
      {port, {:exit_status, status}} when port == child.port -> {output, status}
    after
      max(deadline - System.monotonic_time(:millisecond), 0) -> raise "command timeout: #{output}"
    end
  end

  defp await_ready(child, fixture, ready, deadline, output) do
    receive do
      {port, {:data, bytes}} when port == child.port -> await_ready(child, fixture, ready, deadline, bounded(output <> bytes))
      {port, {:exit_status, status}} when port == child.port -> raise "service exited #{status}: #{output}"
    after
      20 ->
        cond do
          ready.(fixture) -> :ok
          System.monotonic_time(:millisecond) >= deadline -> raise "readiness timeout: #{output}"
          true -> await_ready(child, fixture, ready, deadline, output)
        end
    end
  end

  defp bounded(output), do: binary_part(output, max(byte_size(output) - 65_536, 0), min(byte_size(output), 65_536))

  defp stop(child) do
    group =
      case File.read(child.group_file) do
        {:ok, value} -> String.trim(value)
        _ when is_integer(child.pid) -> to_string(child.pid)
        _ -> nil
      end

    if is_binary(group) do
      System.cmd("pkill", ["-TERM", "-P", group], stderr_to_stdout: true)
      Process.sleep(50)
      System.cmd("kill", ["-TERM", "--", "-#{group}"], stderr_to_stdout: true)
      Process.sleep(50)
      System.cmd("kill", ["-KILL", "--", "-#{group}"], stderr_to_stdout: true)
    end

    if Port.info(child.port), do: Port.close(child.port)
  end
end
