defmodule SymphonyPlus.RuntimeStatusTest do
  use ExUnit.Case, async: true

  alias SymphonyPlus.RuntimeStatus

  test "deduplicates identities using blocked over quota, retrying, and running" do
    snapshot = %{
      running: [%{issue_id: "1", identifier: "GH-1"}],
      retrying: [%{issue_id: "1", identifier: "GH-1", attempt: 2}],
      quota_waiting: [
        %{issue_id: "1", identifier: "GH-1", status: :waiting, harness: :codex, pool_key: "default"}
      ],
      blocked: [%{issue_id: "1", identifier: "GH-1", error: "needs approval"}]
    }

    projected = RuntimeStatus.project(snapshot)

    assert projected.counts == %{running: 0, retrying: 0, quota_waiting: 0, blocked: 1}
    assert [%{issue_id: "1", reason: "needs approval", quota_context: %{pool_key: "default"}}] = projected.blocked
  end

  test "operator-blocked quota records become blocked and retain safe quota context" do
    projected =
      RuntimeStatus.project(%{
        running: [],
        retrying: [],
        blocked: [],
        quota_waiting: [
          %{
            issue_id: "2",
            identifier: "GH-2",
            status: :operator_blocked,
            harness: :codex,
            pool_key: "model",
            last_outcome: "native continuation unavailable",
            raw_payload: "secret"
          }
        ]
      })

    assert projected.quota_waiting == []
    assert [%{reason: "native continuation unavailable", quota_context: context} = blocked] = projected.blocked
    assert context.pool_key == "model"
    refute Map.has_key?(context, :raw_payload)
    refute Map.has_key?(blocked, :raw_payload)
  end

  test "sanitizes blocked reasons and supplies stable missing cues" do
    long = String.duplicate("é", 200)
    assert RuntimeStatus.sanitize_reason(nil) == "Operator action required"
    assert RuntimeStatus.sanitize_reason(%{code: :blocked}) == "%{code: :blocked}"
    assert RuntimeStatus.sanitize_reason("line one\n\e[31mline two") == "line one [31mline two"
    assert long |> RuntimeStatus.sanitize_reason() |> String.graphemes() |> length() == 160

    projected =
      RuntimeStatus.project(%{
        running: [],
        retrying: [],
        blocked: [],
        quota_waiting: [%{issue_id: "3", status: :waiting}]
      })

    assert [%{timing_cue: "Renewal time unavailable"}] = projected.quota_waiting
  end
end
