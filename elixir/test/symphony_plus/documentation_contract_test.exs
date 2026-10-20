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
  end
end
