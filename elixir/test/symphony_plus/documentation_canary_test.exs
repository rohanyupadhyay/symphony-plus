defmodule SymphonyPlus.DocumentationCanaryTest do
  use ExUnit.Case, async: true

  @moduletag :documentation
  @script Path.expand("../../scripts/docs-external-canary", __DIR__)

  for {mode, expected} <- [{"missing", "unavailable"}, {"failed", "failed"}] do
    test "#{mode} fixture records #{expected} and fails the job" do
      root = Path.join(System.tmp_dir!(), "docs-canary-#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(root) end)

      {output, status} =
        System.cmd("bash", [@script],
          env: [
            {"CANARY_FIXTURE_MODE", unquote(mode)},
            {"CANARY_REPORT_DIR", root},
            {"CANARY_APP_PRIVATE_KEY", "secret-sentinel"}
          ],
          stderr_to_stdout: true
        )

      assert status == 1
      assert output =~ "**#{unquote(expected)}**"
      assert File.read!(Path.join(root, "summary.md")) == output
      refute output =~ "secret-sentinel"
    end
  end

  test "stubbed canary keeps credentials out of child arguments and routes labeled findings" do
    root = Path.join(System.tmp_dir!(), "docs-canary-stub-#{System.unique_integer([:positive])}")
    bin = Path.join(root, "bin")
    File.mkdir_p!(bin)
    on_exit(fn -> File.rm_rf!(root) end)
    key = Path.join(root, "fixture.pem")

    assert {_output, 0} =
             System.cmd("openssl", ["genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", key], stderr_to_stdout: true)

    stub(bin, "curl", ~S"""
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%s\n' "$@" > "$CANARY_STUB_DIR/curl.argv"
    cat > "$CANARY_STUB_DIR/curl.config"
    printf '{"token":"fixture-token"}\n'
    """)

    stub(bin, "gh", ~S"""
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$*" == *'-X POST'* ]]; then
      cat > "$CANARY_STUB_DIR/post.json"
      printf '{"number":1}\n'
      exit 0
    fi
    case "$2" in
      repos/owner/private) printf '{"private":true,"default_branch":"main"}\n' ;;
      repos/owner/private/commits/main) printf '%040d\n' 0 ;;
      */check-runs) printf '0\n' ;;
      */status) printf 'success\n' ;;
      'repos/owner/repair/issues?state=open&per_page=100') printf '[]\n' ;;
      *) exit 2 ;;
    esac
    """)

    stub(bin, "git", ~S"""
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "$1" == clone ]]
    [[ -z ${CANARY_CODEX_AUTH_JSON+x} ]]
    printf 'clone-clean\n' > "$CANARY_STUB_DIR/git.obs"
    """)

    stub(bin, "jq", ~S"""
    #!/usr/bin/env bash
    set -euo pipefail
    case "$*" in
      '-r .token // empty') echo fixture-token ;;
      '-r .private') echo true ;;
      '-r .default_branch // empty') echo main ;;
      '-e '*) exit 1 ;;
      '-n '*)
        title=''
        label=''
        while (($#)); do
          if [[ "$1" == --arg ]]; then
            case "$2" in title) title=$3 ;; label) label=$3 ;; esac
            shift 3
          else
            shift
          fi
        done
        printf '{"title":"%s","body":"fixture","labels":["%s"]}\n' "$title" "$label"
        ;;
      *) exit 2 ;;
    esac
    """)

    stub(bin, "codex", ~S"""
    #!/usr/bin/env bash
    set -euo pipefail
    scratch=${CODEX_HOME%/codex-home}
    [[ ! -e "$scratch/app.pem" ]]
    [[ -z ${CANARY_APP_PRIVATE_KEY+x} ]]
    [[ -z ${CANARY_CODEX_AUTH_JSON+x} ]]
    [[ -z ${GH_TOKEN+x} ]]
    [[ -f "$CODEX_HOME/auth.json" ]]
    printf 'codex-clean\n' > "$CANARY_STUB_DIR/codex.obs"
    exit 42
    """)

    {output, status} =
      System.cmd("bash", [@script],
        env: [
          {"PATH", bin <> ":" <> System.get_env("PATH")},
          {"RUNNER_TEMP", root},
          {"CANARY_STUB_DIR", root},
          {"CANARY_REPORT_DIR", Path.join(root, "report")},
          {"CANARY_FIXTURE_MODE", ""},
          {"GITHUB_REF", "refs/heads/main"},
          {"GITHUB_REPOSITORY", "owner/source"},
          {"CANARY_FIXTURE_KIND", "dedicated-private-test"},
          {"CANARY_REPOSITORY", "owner/private"},
          {"CANARY_REPAIR_REPOSITORY", "owner/repair"},
          {"CANARY_REPAIR_LABEL", "symphony-plus"},
          {"CANARY_APP_ID", "1"},
          {"CANARY_INSTALLATION_ID", "2"},
          {"CANARY_APP_PRIVATE_KEY", File.read!(key)},
          {"CANARY_CODEX_AUTH_JSON", ~s({"fixture":true})}
        ],
        stderr_to_stdout: true
      )

    assert status == 1
    assert output =~ "bounded Codex turn: **failed**"
    assert File.read!(Path.join(root, "git.obs")) == "clone-clean\n"
    assert File.read!(Path.join(root, "codex.obs")) == "codex-clean\n"
    refute File.read!(Path.join(root, "curl.argv")) =~ "Bearer "
    assert File.read!(Path.join(root, "curl.config")) =~ ~r/^header = "Authorization: Bearer [\w.-]+"$/
    issue = root |> Path.join("post.json") |> File.read!() |> Jason.decode!()
    assert issue["labels"] == ["symphony-plus"]
    assert String.starts_with?(issue["title"], "[docs-canary:")
    refute output =~ "fixture-token"
  end

  defp stub(bin, name, body) do
    path = Path.join(bin, name)
    File.write!(path, body)
    File.chmod!(path, 0o700)
  end
end
