defmodule SymphonyPlus.ReleaseContractTest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../../.github/workflows/burrito-release.yml", __DIR__)

  test "release workflow publishes Symphony Plus artifacts" do
    workflow = File.read!(@workflow)

    assert workflow =~ "mix release symphony_plus"
    assert workflow =~ ~s(artifact="symphony-plus-${version}-${{ matrix.target }}")
    assert workflow =~ "burrito_out/symphony_plus_"
    assert workflow =~ ~s(--title "Symphony Plus nightly")
  end
end
