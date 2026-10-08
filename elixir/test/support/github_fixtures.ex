defmodule SymphonyElixir.GitHubFixtures do
  @moduledoc false

  @spec pull_request(keyword()) :: map()
  def pull_request(overrides \\ []) do
    sha = Keyword.get(overrides, :head_sha, String.duplicate("a", 40))

    %{
      "number" => Keyword.get(overrides, :number, 7),
      "state" => Keyword.get(overrides, :state, "open"),
      "merged" => Keyword.get(overrides, :merged, false),
      "mergeable" => Keyword.get(overrides, :mergeable, true),
      "head" => %{"sha" => sha, "ref" => "topic", "repo" => %{"full_name" => "octo/repo", "fork" => false}},
      "base" => %{"sha" => String.duplicate("b", 40), "ref" => "main", "repo" => %{"full_name" => "octo/repo"}},
      "labels" => [%{"name" => "symphony"}]
    }
  end

  @spec review(String.t()) :: map()
  def review(state \\ "APPROVED"), do: %{"id" => 1, "state" => state, "user" => %{"login" => "reviewer"}}

  @spec checks(String.t()) :: map()
  def checks(sha), do: %{"total_count" => 1, "check_runs" => [%{"head_sha" => sha, "conclusion" => "success"}]}
end
