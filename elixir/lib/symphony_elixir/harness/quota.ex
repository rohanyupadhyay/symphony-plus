defmodule SymphonyElixir.Harness.Quota do
  @moduledoc "Harness-neutral quota exhaustion and native continuation value contracts."

  defmodule ContinuationReference do
    @moduledoc "Non-secret native continuation identity bound to one issue workspace."

    alias SymphonyElixir.Harness.Quota

    @enforce_keys [:harness, :native_id, :issue_id, :workspace_key]
    defstruct [:harness, :native_id, :issue_id, :workspace_key]

    @type t :: %__MODULE__{
            harness: :codex,
            native_id: String.t(),
            issue_id: String.t(),
            workspace_key: String.t()
          }

    @spec new(map()) :: {:ok, t()} | {:error, term()}
    def new(attrs) when is_map(attrs) do
      with :ok <- Quota.validate_harness(Map.get(attrs, :harness)),
           {:ok, native_id} <- Quota.validate_string(attrs, :native_id, 512),
           {:ok, issue_id} <- Quota.validate_string(attrs, :issue_id, 512),
           {:ok, workspace_key} <- Quota.validate_string(attrs, :workspace_key, 256) do
        {:ok,
         %__MODULE__{
           harness: :codex,
           native_id: native_id,
           issue_id: issue_id,
           workspace_key: workspace_key
         }}
      end
    end

    def new(_attrs), do: {:error, {:invalid_field, :continuation}}
  end

  defmodule QuotaSignal do
    @moduledoc "Normalized, allowlisted quota exhaustion signal."

    alias SymphonyElixir.Harness.Quota

    @allowed_keys [:harness, :pool_key, :renewal_at, :observed_at, :continuation]
    @enforce_keys [:harness, :pool_key, :observed_at]
    defstruct [:harness, :pool_key, :renewal_at, :observed_at, :continuation]

    @type t :: %__MODULE__{
            harness: :codex,
            pool_key: String.t(),
            renewal_at: DateTime.t() | nil,
            observed_at: DateTime.t(),
            continuation: ContinuationReference.t() | nil
          }

    @spec new(map()) :: {:ok, t()} | {:error, term()}
    def new(attrs) when is_map(attrs) do
      with :ok <- reject_unknown_keys(attrs),
           :ok <- Quota.validate_harness(Map.get(attrs, :harness)),
           {:ok, pool_key} <- Quota.validate_string(attrs, :pool_key, 512),
           {:ok, observed_at} <- validate_datetime(attrs, :observed_at, required: true),
           {:ok, renewal_at} <- validate_datetime(attrs, :renewal_at, required: false),
           :ok <- validate_future_renewal(renewal_at, observed_at),
           {:ok, continuation} <- validate_continuation(Map.get(attrs, :continuation)) do
        {:ok,
         %__MODULE__{
           harness: :codex,
           pool_key: pool_key,
           renewal_at: renewal_at,
           observed_at: observed_at,
           continuation: continuation
         }}
      end
    end

    def new(_attrs), do: {:error, {:invalid_field, :quota_signal}}

    defp reject_unknown_keys(attrs) do
      case Map.keys(attrs) -- @allowed_keys do
        [] -> :ok
        [key | _] -> {:error, {:secret_field, key}}
      end
    end

    defp validate_datetime(attrs, key, opts) do
      required? = Keyword.fetch!(opts, :required)

      case Map.get(attrs, key) do
        %DateTime{} = value -> {:ok, value}
        nil -> if required?, do: {:error, {:invalid_field, key}}, else: {:ok, nil}
        _ -> {:error, {:invalid_field, key}}
      end
    end

    defp validate_future_renewal(nil, _observed_at), do: :ok

    defp validate_future_renewal(renewal_at, observed_at) do
      if DateTime.after?(renewal_at, observed_at), do: :ok, else: {:error, :renewal_not_future}
    end

    defp validate_continuation(nil), do: {:ok, nil}
    defp validate_continuation(%ContinuationReference{} = continuation), do: {:ok, continuation}
    defp validate_continuation(_value), do: {:error, {:invalid_field, :continuation}}
  end

  @doc false
  @spec validate_harness(term()) :: :ok | {:error, {:invalid_harness, term()}}
  def validate_harness(:codex), do: :ok
  def validate_harness(value), do: {:error, {:invalid_harness, value}}

  @doc false
  @spec validate_string(map(), atom(), pos_integer()) ::
          {:ok, String.t()} | {:error, {:invalid_field, atom()}}
  def validate_string(attrs, field, max_length) do
    case Map.get(attrs, field) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed != "" and byte_size(trimmed) <= max_length,
          do: {:ok, trimmed},
          else: {:error, {:invalid_field, field}}

      _ ->
        {:error, {:invalid_field, field}}
    end
  end
end
