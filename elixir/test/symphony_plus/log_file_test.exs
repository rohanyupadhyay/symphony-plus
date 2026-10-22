defmodule SymphonyPlus.LogFileTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.LogFile

  test "default_log_file/0 uses the current working directory" do
    assert LogFile.default_log_file() == Path.join(File.cwd!(), "log/symphony-plus.log")
  end

  test "default_log_file/1 builds the log path under a custom root" do
    assert LogFile.default_log_file("/tmp/symphony-plus-logs") == "/tmp/symphony-plus-logs/log/symphony-plus.log"
  end
end
