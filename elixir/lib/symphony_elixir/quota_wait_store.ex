defmodule SymphonyElixir.QuotaWaitStore do
  @moduledoc "Validated atomic persistence for issue-scoped quota waits."

  alias SymphonyElixir.PathSafety

  @fields ~w(version issue_id issue_identifier harness pool_key status renewal_at next_recheck_at workspace_key continuation last_outcome observed_at updated_at)
  @statuses ~w(waiting eligible resuming operator_blocked)

  @spec put(Path.t(), map()) :: :ok | {:error, term()}
  def put(workspace_root, record) when is_binary(workspace_root) and is_map(record) do
    with {:ok, normalized} <- validate(record),
         {:ok, directory} <- store_directory(workspace_root),
         :ok <- File.mkdir_p(directory) do
      path = record_path(directory, normalized["issue_id"])
      temporary = path <> ".tmp-#{System.unique_integer([:positive])}"

      with :ok <- File.write(temporary, Jason.encode!(normalized)),
           :ok <- File.rename(temporary, path) do
        :ok
      else
        {:error, reason} ->
          File.rm(temporary)
          {:error, {:quota_wait_write_failed, reason}}
      end
    end
  end

  def put(_workspace_root, _record), do: {:error, :invalid_workspace_root}

  @spec fetch(Path.t(), String.t()) :: {:ok, map()} | :not_found | {:error, term()}
  def fetch(workspace_root, issue_id) when is_binary(workspace_root) do
    with :ok <- validate_issue_id(issue_id),
         {:ok, directory} <- store_directory(workspace_root) do
      path = record_path(directory, issue_id)

      case File.read(path) do
        {:ok, contents} -> decode_record(path, contents)
        {:error, :enoent} -> :not_found
        {:error, reason} -> {:error, {:quota_wait_read_failed, path, reason}}
      end
    end
  end

  def fetch(_workspace_root, _issue_id), do: {:error, :invalid_workspace_root}

  @spec list(Path.t()) :: {:ok, [map()]} | {:error, term()}
  def list(workspace_root) when is_binary(workspace_root) do
    with {:ok, directory} <- store_directory(workspace_root) do
      case File.ls(directory) do
        {:ok, filenames} ->
          list_records(directory, filenames)

        {:error, :enoent} ->
          {:ok, []}

        {:error, reason} ->
          {:error, {:quota_wait_list_failed, directory, reason}}
      end
    end
  end

  def list(_workspace_root), do: {:error, :invalid_workspace_root}

  defp list_records(directory, filenames) do
    filenames
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, &read_record(directory, &1, &2))
    |> reverse_records()
  end

  defp read_record(directory, filename, {:ok, records}) do
    path = Path.join(directory, filename)

    with {:ok, contents} <- File.read(path),
         {:ok, record} <- decode_record(path, contents) do
      {:cont, {:ok, [record | records]}}
    else
      {:error, {:corrupt_quota_wait, _, _} = reason} -> {:halt, {:error, reason}}
      {:error, reason} -> {:halt, {:error, {:quota_wait_read_failed, path, reason}}}
    end
  end

  defp reverse_records({:ok, records}), do: {:ok, Enum.reverse(records)}
  defp reverse_records(error), do: error

  @spec delete(Path.t(), String.t()) :: :ok | {:error, term()}
  def delete(workspace_root, issue_id) when is_binary(workspace_root) do
    with :ok <- validate_issue_id(issue_id),
         {:ok, directory} <- store_directory(workspace_root) do
      case File.rm(record_path(directory, issue_id)) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        {:error, reason} -> {:error, {:quota_wait_delete_failed, reason}}
      end
    end
  end

  def delete(_workspace_root, _issue_id), do: {:error, :invalid_workspace_root}

  defp decode_record(path, contents) do
    case Jason.decode(contents) do
      {:ok, record} -> validate(record)
      {:error, reason} -> {:error, {:corrupt_quota_wait, path, reason}}
    end
  end

  defp validate(record) do
    normalized = Map.take(record, @fields)

    with :ok <- validate_version(normalized["version"]),
         :ok <- validate_string(normalized, "issue_id", 512),
         :ok <- validate_string(normalized, "issue_identifier", 256),
         :ok <- validate_harness(normalized["harness"]),
         :ok <- validate_string(normalized, "pool_key", 512),
         :ok <- validate_status(normalized["status"]),
         :ok <- validate_optional_timestamp(normalized["renewal_at"]),
         :ok <- validate_timestamp(normalized["next_recheck_at"]),
         :ok <- validate_workspace_key(normalized["workspace_key"]),
         :ok <- validate_continuation(normalized["continuation"], normalized),
         :ok <- validate_string(normalized, "last_outcome", 128),
         :ok <- validate_timestamp(normalized["observed_at"]),
         :ok <- validate_timestamp(normalized["updated_at"]) do
      {:ok, normalized}
    else
      {:error, reason} -> {:error, {:invalid_quota_wait, reason}}
    end
  end

  defp validate_version(1), do: :ok
  defp validate_version(_value), do: {:error, :unknown_version}
  defp validate_harness("codex"), do: :ok
  defp validate_harness(_value), do: {:error, :invalid_harness}
  defp validate_status(value) when value in @statuses, do: :ok
  defp validate_status(_value), do: {:error, :invalid_status}

  defp validate_string(record, field, max_length) do
    case record[field] do
      value when is_binary(value) ->
        if String.trim(value) != "" and byte_size(value) <= max_length,
          do: :ok,
          else: {:error, {:invalid_field, field}}

      _ ->
        {:error, {:invalid_field, field}}
    end
  end

  defp validate_timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, _datetime, 0} -> :ok
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp validate_timestamp(_value), do: {:error, :invalid_timestamp}
  defp validate_optional_timestamp(nil), do: :ok
  defp validate_optional_timestamp(value), do: validate_timestamp(value)

  defp validate_workspace_key(value) do
    with :ok <- validate_string(%{"workspace_key" => value}, "workspace_key", 256) do
      if value in [".", ".."] or String.contains?(value, ["/", "\\"]),
        do: {:error, :invalid_workspace_key},
        else: :ok
    end
  end

  defp validate_continuation(nil, _record), do: :ok

  defp validate_continuation(continuation, record) when is_map(continuation) do
    allowed = Map.take(continuation, ~w(harness native_id issue_id workspace_key))

    with true <- map_size(allowed) == 4,
         "codex" <- allowed["harness"],
         :ok <- validate_string(allowed, "native_id", 512),
         true <- allowed["issue_id"] == record["issue_id"],
         true <- allowed["workspace_key"] == record["workspace_key"] do
      :ok
    else
      _ -> {:error, :invalid_continuation}
    end
  end

  defp validate_continuation(_value, _record), do: {:error, :invalid_continuation}

  defp validate_issue_id(issue_id) when is_binary(issue_id) do
    if String.trim(issue_id) != "" and byte_size(issue_id) <= 512 and
         not String.contains?(issue_id, ["/", "\\", ".."]),
       do: :ok,
       else: {:error, :invalid_issue_id}
  end

  defp validate_issue_id(_issue_id), do: {:error, :invalid_issue_id}

  defp store_directory(workspace_root) do
    case PathSafety.canonicalize(workspace_root) do
      {:ok, canonical_root} -> {:ok, Path.join([canonical_root, ".symphony", "quota-waits"])}
      {:error, _reason} -> {:error, :invalid_workspace_root}
    end
  end

  defp record_path(directory, issue_id) do
    digest = :crypto.hash(:sha256, issue_id) |> Base.encode16(case: :lower)
    Path.join(directory, digest <> ".json")
  end
end
