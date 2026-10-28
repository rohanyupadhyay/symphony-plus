defmodule SymphonyPlus.ReleaseContractTest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../../.github/workflows/burrito-release.yml", __DIR__)
  @script Path.expand("../../scripts/docs-release-smoke", __DIR__)

  test "release workflow publishes Symphony Plus artifacts" do
    workflow = File.read!(@workflow)

    assert workflow =~ "mix release symphony_plus"
    assert workflow =~ ~s(artifact="symphony-plus-${version}-${{ matrix.target }}")
    assert workflow =~ "burrito_out/symphony_plus_"
    assert workflow =~ ~s(--title "Symphony Plus nightly")
    assert workflow =~ "bash elixir/scripts/docs-release-smoke"
    assert workflow =~ "needs: [build, smoke]"
  end

  test "a broken candidate cannot satisfy the documented release smoke" do
    root = Path.join(System.tmp_dir!(), "release-smoke-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    asset = Path.join(root, "symphony-plus-test-linux_x86_64")

    try do
      File.write!(asset, "#!/usr/bin/env bash\nexit 1\n")
      {digest, 0} = System.cmd("shasum", ["-a", "256", asset])
      File.write!(asset <> ".sha256", digest)
      {output, status} = System.cmd("bash", [@script, asset, "linux_x86_64", "test"], stderr_to_stdout: true)
      assert status != 0
      assert output =~ "candidate exited before HTTP readiness"
    after
      File.rm_rf!(root)
    end
  end
end
