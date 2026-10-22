defmodule SymphonyPlus.DocumentationContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)

  test "operator-facing documentation uses canonical names" do
    assert File.exists?(Path.join(@root, ".symphony-plus/WORKFLOW.md"))
    refute File.exists?(Path.join(@root, ".symphony/WORKFLOW.md"))

    readme = File.read!(Path.join(@root, "README.md"))
    assert readme =~ "# Symphony Plus"
    assert readme =~ ".symphony-plus/WORKFLOW.md"
    assert readme =~ "OpenAI Symphony"

    implementation_readme = File.read!(Path.join(@root, "elixir/README.md"))
    assert implementation_readme =~ "rohanyupadhyay/symphony-plus/releases/tag/nightly"
    refute implementation_readme =~ "openai/symphony/releases/tag/nightly"
  end
end
