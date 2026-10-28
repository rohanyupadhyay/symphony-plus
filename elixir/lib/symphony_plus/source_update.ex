defmodule SymphonyPlus.SourceUpdate do
  @moduledoc "Safe Git boundary for source-checkout automatic updates."

  @sha ~r/\A[0-9a-f]{40}\z/

  @type candidate :: %{revision: String.t(), default_branch: String.t(), detected_at: DateTime.t()}

  @spec discover(Path.t(), String.t()) :: {:ok, candidate() | :current} | {:error, term()}
  def discover(root, remote \\ "origin") do
    with :ok <- eligible(root, remote),
         {:ok, branch} <- default_branch(root, remote),
         {:ok, running} <- git(root, ["rev-parse", "HEAD"]),
         {:ok, revision} <- git(root, ["rev-parse", "#{remote}/#{branch}"]),
         :ok <- validate_sha(revision),
         true <- ancestor?(root, running, revision) || {:error, :divergent_history} do
      if revision == running do
        {:ok, :current}
      else
        {:ok, %{revision: revision, default_branch: branch, detected_at: DateTime.utc_now()}}
      end
    end
  end

  @spec prepare(Path.t(), candidate(), String.t()) :: {:ok, Path.t()} | {:error, term()}
  def prepare(root, %{revision: revision}, command) do
    base = Path.join(Path.dirname(root), ".symphony-plus-updates")
    path = Path.join(base, "#{revision}-#{System.pid()}")
    lock = Path.join(root, ".git/symphony-plus-prepare.lock")

    case File.mkdir(lock) do
      :ok ->
        try do
          with :ok <- File.mkdir_p(base),
               :ok <- remove_owned_worktree(root, path),
               {:ok, _} <- git(root, ["worktree", "add", "--detach", path, revision]),
               {_, 0} <- System.cmd("bash", ["-lc", command], cd: Path.join(path, "elixir"), stderr_to_stdout: true),
               true <- prepared_executable?(path) || {:error, :prepared_executable_missing} do
            {:ok, path}
          else
            {:error, _} = error -> error
            {output, status} -> {:error, {:preparation_failed, status, bounded(output)}}
          end
        after
          File.rmdir(lock)
        end

      {:error, :eexist} ->
        {:error, :preparation_locked}

      {:error, reason} ->
        {:error, {:preparation_lock_failed, reason}}
    end
  end

  defp prepared_executable?(path) do
    case File.stat(Path.join(path, "elixir/bin/symphony-plus")) do
      {:ok, %{type: :regular, mode: mode}} -> Bitwise.band(mode, 0o111) != 0
      _ -> false
    end
  end

  @spec eligible(Path.t(), String.t()) :: :ok | {:error, term()}
  def eligible(root, remote) do
    with true <- Path.type(root) == :absolute || {:error, :installation_root_not_absolute},
         {:ok, top} <- git(root, ["rev-parse", "--show-toplevel"]),
         true <- Path.expand(top) == Path.expand(root) || {:error, :wrong_installation_root},
         {:ok, ""} <- git(root, ["status", "--porcelain"]),
         {:ok, branch} <- git(root, ["symbolic-ref", "--short", "HEAD"]),
         true <- branch != "" || {:error, :detached_head},
         {:ok, _} <- git(root, ["remote", "get-url", remote]),
         {:ok, _} <- git(root, ["fetch", "--prune", remote]) do
      :ok
    else
      {:ok, _dirty} -> {:error, :dirty_checkout}
      {:error, _} = error -> error
      false -> {:error, :ineligible_checkout}
    end
  end

  @spec candidate_still_current?(Path.t(), String.t(), candidate()) :: boolean()
  def candidate_still_current?(root, remote, candidate) do
    revision = candidate.revision

    with {:ok, _} <- git(root, ["fetch", "--prune", remote]),
         {:ok, ^revision} <- git(root, ["rev-parse", "#{remote}/#{candidate.default_branch}"]) do
      true
    else
      _ -> false
    end
  end

  defp default_branch(root, remote) do
    case git(root, ["symbolic-ref", "--short", "refs/remotes/#{remote}/HEAD"]) do
      {:ok, value} -> {:ok, String.replace_prefix(value, remote <> "/", "")}
      error -> error
    end
  end

  defp ancestor?(root, old, new) do
    case System.cmd("git", ["merge-base", "--is-ancestor", old, new], cd: root, stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp remove_owned_worktree(root, path) do
    if File.exists?(path) do
      case git(root, ["worktree", "remove", "--force", path]) do
        {:ok, _} -> :ok
        error -> error
      end
    else
      :ok
    end
  end

  defp git(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, status} -> {:error, {:git_failed, status, bounded(output)}}
    end
  rescue
    error -> {:error, {:command_failed, Exception.message(error)}}
  end

  defp validate_sha(value), do: if(Regex.match?(@sha, value), do: :ok, else: {:error, :invalid_revision})

  defp bounded(value) do
    value |> to_string() |> String.replace(~r/[\r\n\t]+/, " ") |> String.slice(0, 240)
  end
end
