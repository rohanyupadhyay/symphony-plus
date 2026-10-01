defmodule SymphonyElixir.HarnessQuotaTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.Harness.Quota.{ContinuationReference, QuotaSignal}

  test "builds a normalized codex quota signal and continuation reference" do
    now = ~U[2026-10-01 00:00:00Z]
    renewal_at = ~U[2026-10-01 01:00:00Z]

    assert {:ok, continuation} =
             ContinuationReference.new(%{
               harness: :codex,
               native_id: "thread-123",
               issue_id: "issue-8",
               workspace_key: "GH-8"
             })

    assert {:ok, signal} =
             QuotaSignal.new(%{
               harness: :codex,
               pool_key: "codex:account:default",
               renewal_at: renewal_at,
               observed_at: now,
               continuation: continuation
             })

    assert signal.harness == :codex
    assert signal.pool_key == "codex:account:default"
    assert signal.renewal_at == renewal_at
    assert signal.continuation == continuation
  end

  test "rejects unsupported harnesses, invalid renewal times, and secret-like fields" do
    now = ~U[2026-10-01 00:00:00Z]

    assert {:error, {:invalid_harness, :claude}} =
             QuotaSignal.new(%{harness: :claude, pool_key: "default", observed_at: now})

    assert {:error, :renewal_not_future} =
             QuotaSignal.new(%{
               harness: :codex,
               pool_key: "default",
               renewal_at: now,
               observed_at: now
             })

    assert {:error, {:secret_field, :raw_provider_payload}} =
             QuotaSignal.new(%{
               harness: :codex,
               pool_key: "default",
               observed_at: now,
               raw_provider_payload: %{"token" => "secret"}
             })

    assert {:error, {:invalid_field, :pool_key}} =
             QuotaSignal.new(%{harness: :codex, pool_key: " ", observed_at: now})

    assert {:error, {:invalid_field, :quota_signal}} = QuotaSignal.new(:invalid)

    assert {:error, {:invalid_field, :observed_at}} =
             QuotaSignal.new(%{harness: :codex, pool_key: "default", observed_at: "invalid"})

    assert {:error, {:invalid_field, :continuation}} =
             QuotaSignal.new(%{
               harness: :codex,
               pool_key: "default",
               observed_at: now,
               continuation: %{}
             })
  end

  test "continuation references require non-empty bounded issue and workspace bindings" do
    assert {:error, {:invalid_field, :continuation}} = ContinuationReference.new(:invalid)

    assert {:error, {:invalid_field, :native_id}} =
             ContinuationReference.new(%{
               harness: :codex,
               native_id: "",
               issue_id: "issue-8",
               workspace_key: "GH-8"
             })

    assert {:error, {:invalid_field, :workspace_key}} =
             ContinuationReference.new(%{
               harness: :codex,
               native_id: "thread-123",
               issue_id: "issue-8",
               workspace_key: String.duplicate("x", 257)
             })

    assert {:error, {:invalid_field, :issue_id}} =
             ContinuationReference.new(%{
               harness: :codex,
               native_id: "thread-123",
               issue_id: nil,
               workspace_key: "GH-8"
             })
  end
end
