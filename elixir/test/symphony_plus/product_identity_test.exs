defmodule SymphonyPlus.ProductIdentityTest do
  use ExUnit.Case, async: true

  test "canonical product identity is internally consistent" do
    project = Mix.Project.config()

    assert project[:app] == :symphony_plus
    assert project[:escript][:name] == "symphony-plus"
    assert project[:escript][:path] == "bin/symphony-plus"
    assert Keyword.has_key?(project[:releases], :symphony_plus)
    assert Code.ensure_loaded?(SymphonyPlus)
    refute Code.ensure_loaded?(Module.concat(["Symphony", "Elixir"]))
  end

  test "maintained files contain no unclassified legacy product identity" do
    {output, status} =
      System.cmd("elixir", ["scripts/audit_product_identity.exs"], stderr_to_stdout: true)

    assert status == 0, output
    assert output =~ "Product identity audit passed"
  end
end
