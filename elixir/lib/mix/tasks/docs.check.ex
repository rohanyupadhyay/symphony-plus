defmodule Mix.Tasks.Docs.Check do
  @moduledoc "Checks generated facts and maintained operator references without writing files."
  @shortdoc "Check generated documentation without writing files"
  use Mix.Task
  @impl Mix.Task
  def run([]) do
    Mix.Task.run("compile")

    case SymphonyPlus.Documentation.check(Path.expand("..")) do
      :ok -> Mix.shell().info("Generated documentation is current.")
      {:error, findings} -> Mix.raise(Enum.map_join(findings, "\n", &"#{&1.path}: #{&1.message}"))
    end
  end
end
