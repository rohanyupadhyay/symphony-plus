#!/usr/bin/env elixir

root = Path.expand("../..", __DIR__)

{output, 0} =
  System.cmd("git", ["ls-files", "--cached", "--others", "--exclude-standard"], cd: root)

legacy_display = Regex.compile!("\\b" <> "Sym" <> "phony" <> "\\b(?! Plus)")
legacy_slug = Regex.compile!("\\b" <> "sym" <> "phony" <> "\\b(?![-_]plus)")
legacy_env = Regex.compile!("\\b" <> "SYM" <> "PHONY_(?!PLUS_)")

allowlist_path = Path.join(root, "elixir/test/fixtures/product_identity_allowlist.txt")
allowed_classifications = ~w(upstream historical immutable_external)

allowlisted_literals =
  allowlist_path
  |> File.stream!()
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  |> Enum.map(fn entry ->
    case String.split(entry, ~r/\s+/, parts: 2) do
      [classification, literal] ->
        if classification in allowed_classifications and literal != "" do
          literal
        else
          IO.puts(:stderr, "#{allowlist_path}: invalid classified allowlist entry: #{entry}")
          System.halt(1)
        end

      _invalid ->
        IO.puts(:stderr, "#{allowlist_path}: invalid classified allowlist entry: #{entry}")
        System.halt(1)
    end
  end)

excluded_prefixes = ["specs/gh-18-rename-symphony-plus/"]
excluded_files = [
  "elixir/test/fixtures/product_identity_allowlist.txt",
  "elixir/test/symphony_plus/documentation_contract_test.exs",
  "elixir/test/symphony_plus/product_identity_test.exs"
]

violations =
  output
  |> String.split("\n", trim: true)
  |> Enum.reject(fn path ->
    path in excluded_files or Enum.any?(excluded_prefixes, &String.starts_with?(path, &1))
  end)
  |> Enum.flat_map(fn path ->
    absolute = Path.join(root, path)

    if not File.exists?(absolute) do
      []
    else

      path_findings =
        if Regex.match?(legacy_slug, path), do: ["#{path}: path contains the legacy slug"], else: []

      case File.read(absolute) do
        {:ok, contents} ->
          if String.valid?(contents) do
            contents
            |> String.split("\n")
            |> Enum.with_index(1)
            |> Enum.filter(fn {line, _line_number} ->
              sanitized = Enum.reduce(allowlisted_literals, line, &String.replace(&2, &1, ""))

              Regex.match?(legacy_display, sanitized) or Regex.match?(legacy_slug, sanitized) or
                Regex.match?(legacy_env, sanitized)
            end)
            |> Enum.map(fn {_line, line_number} -> "#{path}:#{line_number}: legacy product identity" end)
            |> Kernel.++(path_findings)
          else
            path_findings
          end

        {:error, _reason} ->
          path_findings
      end
    end
  end)

case violations do
  [] ->
    IO.puts("Product identity audit passed")

  findings ->
    Enum.each(findings, &IO.puts(:stderr, &1))
    System.halt(1)
end
