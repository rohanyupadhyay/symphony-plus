defmodule SymphonyElixir.GitHub.MergeQueue.State do
  @moduledoc """
  Durable value types used by the GitHub merge queue.

  Queue entries are identified by pull-request number and admitted head SHA. A
  changed head is therefore a new generation rather than a mutation of evidence
  that was approved for an older revision.
  """

  @sha ~r/\A[0-9a-f]{40}\z/i
  @repo ~r/\A[^\/\s]+\/[^\/\s]+\z/

  defmodule Entry do
    @moduledoc "A durable queue admission."
    @enforce_keys [:repository, :target_branch, :pr_number, :source_head_sha, :admission_sequence, :generation]
    defstruct @enforce_keys ++
                [
                  originating_issue: nil,
                  dependencies: [],
                  dependency_blocker: nil,
                  admitted_at: nil,
                  target_sha: nil,
                  candidate_sha: nil
                ]

    @type t :: %__MODULE__{
            repository: String.t(),
            target_branch: String.t(),
            pr_number: pos_integer(),
            source_head_sha: String.t(),
            admission_sequence: non_neg_integer(),
            generation: {pos_integer(), String.t()},
            originating_issue: pos_integer() | nil,
            dependencies: [pos_integer()],
            dependency_blocker: atom() | nil,
            admitted_at: String.t() | nil,
            target_sha: String.t() | nil,
            candidate_sha: String.t() | nil
          }
  end

  defmodule Candidate do
    @moduledoc "Exact source, target, and post-update revisions validated for merge."
    @enforce_keys [:source_head_sha, :target_sha, :candidate_sha]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            source_head_sha: String.t(),
            target_sha: String.t(),
            candidate_sha: String.t()
          }
  end

  defmodule Outcome do
    @moduledoc "Durable result and recovery instruction for a queue generation."
    @enforce_keys [:kind, :reason]
    defstruct @enforce_keys ++ [recovery: nil, candidate_sha: nil]

    @type kind :: :merged | :update_required | :blocked | :cancelled
    @type t :: %__MODULE__{kind: kind(), reason: atom(), recovery: String.t() | nil, candidate_sha: String.t() | nil}
  end

  @spec new_entry(map()) :: {:ok, Entry.t()} | {:error, atom()}
  def new_entry(attrs) when is_map(attrs) do
    values = entry_values(attrs)

    with :ok <- validate_entry(values),
         {:ok, dependencies} <- normalize_dependencies(values.dependencies, values.number) do
      {:ok, build_entry(values, dependencies)}
    end
  end

  def new_entry(_attrs), do: {:error, :invalid_entry}

  defp entry_values(attrs) do
    %{
      repository: attr(attrs, "repository", :repository),
      branch: attr(attrs, "target_branch", :target_branch),
      number: attr(attrs, "pr_number", :pr_number),
      sha: attr(attrs, "source_head_sha", :source_head_sha),
      sequence: attr(attrs, "admission_sequence", :admission_sequence),
      issue: attr(attrs, "originating_issue", :originating_issue),
      admitted_at: attr(attrs, "admitted_at", :admitted_at),
      target_sha: attr(attrs, "target_sha", :target_sha),
      candidate_sha: attr(attrs, "candidate_sha", :candidate_sha),
      dependencies: attr(attrs, "dependencies", :dependencies) || []
    }
  end

  defp attr(attrs, string_key, atom_key), do: Map.get(attrs, string_key, Map.get(attrs, atom_key))

  defp validate_entry(values) do
    with :ok <- validate_repository(values.repository),
         :ok <- validate_present(values.branch, :invalid_target_branch),
         :ok <- validate_positive(values.number, :invalid_pr_number),
         :ok <- validate_sha(values.sha) do
      validate_sequence(values.sequence)
    end
  end

  defp build_entry(values, dependencies) do
    sha = String.downcase(values.sha)

    %Entry{
      repository: values.repository,
      target_branch: values.branch,
      pr_number: values.number,
      source_head_sha: sha,
      originating_issue: values.issue,
      admission_sequence: values.sequence,
      admitted_at: values.admitted_at,
      target_sha: values.target_sha,
      candidate_sha: values.candidate_sha,
      dependencies: dependencies,
      generation: {values.number, sha}
    }
  end

  @spec to_checkpoint(Entry.t()) :: map()
  def to_checkpoint(%Entry{} = entry) do
    entry
    |> Map.from_struct()
    |> Map.drop([:generation, :dependency_blocker])
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.put("version", 1)
    |> Map.put("kind", "merge_queue_admission")
  end

  @spec from_checkpoint(map()) :: {:ok, Entry.t()} | {:error, atom()}
  def from_checkpoint(%{"version" => 1, "kind" => "merge_queue_admission"} = checkpoint),
    do: new_entry(checkpoint)

  def from_checkpoint(_checkpoint), do: {:error, :invalid_checkpoint}

  @spec fresh?(Candidate.t(), String.t(), String.t()) :: boolean()
  def fresh?(%Candidate{} = candidate, pr_head_sha, target_sha) do
    candidate.candidate_sha == pr_head_sha and candidate.target_sha == target_sha
  end

  @spec normalize_dependencies(list(), pos_integer()) :: {:ok, [pos_integer()]} | {:error, atom()}
  def normalize_dependencies(values, _own_number) when is_list(values) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case dependency_number(value) do
        {:ok, number} -> {:cont, {:ok, [number | acc]}}
        :error -> {:halt, {:error, :invalid_dependency}}
      end
    end)
    |> case do
      {:ok, dependencies} -> {:ok, dependencies |> Enum.uniq() |> Enum.sort()}
      error -> error
    end
  end

  def normalize_dependencies(_values, _own_number), do: {:error, :invalid_dependency}

  defp dependency_number(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp dependency_number(value) when is_binary(value) do
    case Integer.parse(String.trim_leading(String.trim(value), "#")) do
      {number, ""} when number > 0 -> {:ok, number}
      _ -> :error
    end
  end

  defp dependency_number(_value), do: :error

  defp validate_repository(value) when is_binary(value), do: if(value =~ @repo, do: :ok, else: {:error, :invalid_repository})
  defp validate_repository(_value), do: {:error, :invalid_repository}
  defp validate_present(value, _reason) when is_binary(value) and byte_size(value) > 0, do: :ok
  defp validate_present(_value, reason), do: {:error, reason}
  defp validate_positive(value, _reason) when is_integer(value) and value > 0, do: :ok
  defp validate_positive(_value, reason), do: {:error, reason}
  defp validate_sha(value) when is_binary(value), do: if(value =~ @sha, do: :ok, else: {:error, :invalid_sha})
  defp validate_sha(_value), do: {:error, :invalid_sha}
  defp validate_sequence(value) when is_integer(value) and value >= 0, do: :ok
  defp validate_sequence(_value), do: {:error, :invalid_admission_sequence}
end
