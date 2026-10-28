defmodule Mix.Tasks.Docs.Generate do
  @moduledoc "Regenerates the bounded configuration and build reference."
  @shortdoc "Regenerate schema and CLI reference facts"
  use Mix.Task
  @impl Mix.Task
  def run([]) do
    Mix.Task.run("compile")

    case SymphonyPlus.Documentation.render(Path.expand("..")) do
      {:ok, rendered} -> File.write!("docs/configuration-reference.md", rendered)
      {:error, reason} -> Mix.raise("Cannot generate documentation: #{reason}")
    end
  end
end
