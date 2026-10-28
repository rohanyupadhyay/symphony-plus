defmodule SymphonyPlus.MixProject do
  use Mix.Project

  def project do
    [
      app: :symphony_plus,
      version: "0.0.3",
      elixir: "~> 1.19",
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [
        summary: [
          threshold: 100
        ],
        ignore_modules: [
          SymphonyPlus.Asana.Client,
          SymphonyPlus.Config,
          SymphonyPlus.GitHub.AppCLI,
          SymphonyPlus.GitHub.AppProfile,
          SymphonyPlus.GitHub.Auth,
          SymphonyPlus.GitHub.AuthCache,
          SymphonyPlus.GitHub.Client,
          SymphonyPlus.GitHub.GitPush,
          SymphonyPlus.GitHub.MergeQueue.Backend,
          SymphonyPlus.GitLab.Client,
          SymphonyPlus.Jira.Client,
          SymphonyPlus.Linear.Client,
          SymphonyPlus.SpecsCheck,
          SymphonyPlus.Orchestrator,
          SymphonyPlus.Orchestrator.State,
          SymphonyPlus.ProjectRegistry,
          SymphonyPlus.ProjectRuntime,
          SymphonyPlus.ProjectRuntimeSupervisor,
          SymphonyPlus.QuotaWaitStore,
          SymphonyPlus.AgentRunner,
          SymphonyPlus.Application,
          SymphonyPlus.CLI,
          SymphonyPlus.Codex.AppServer,
          SymphonyPlus.Codex.DynamicTool,
          SymphonyPlus.HttpServer,
          SymphonyPlus.StatusDashboard,
          SymphonyPlus.SourceUpdate,
          SymphonyPlus.UpdateManager,
          SymphonyPlus.LogFile,
          SymphonyPlus.Workspace,
          SymphonyPlusWeb.DashboardLive,
          SymphonyPlusWeb.Endpoint,
          SymphonyPlusWeb.ErrorHTML,
          SymphonyPlusWeb.ErrorJSON,
          SymphonyPlusWeb.Layouts,
          SymphonyPlusWeb.ObservabilityApiController,
          SymphonyPlusWeb.Presenter,
          SymphonyPlusWeb.StaticAssetController,
          SymphonyPlusWeb.StaticAssets,
          SymphonyPlusWeb.Router,
          SymphonyPlusWeb.Router.Helpers
        ]
      ],
      test_ignore_filters: [
        "test/support/github_fixtures.ex",
        "test/support/snapshot_support.exs",
        "test/support/test_support.exs",
        "test/support/documentation_support.exs"
      ],
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      escript: escript(),
      releases: releases(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {SymphonyPlus.Application, []},
      extra_applications: [:logger, :public_key]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.8"},
      {:floki, ">= 0.30.0", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix, "~> 1.8.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.12"},
      {:solid, "~> 1.2"},
      {:ecto, "~> 3.13"},
      {:burrito, "~> 1.5", only: :prod, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      build: ["escript.build"],
      lint: ["specs.check", "credo --strict"]
    ]
  end

  defp escript do
    [
      app: nil,
      main_module: SymphonyPlus.CLI,
      name: "symphony-plus",
      path: "bin/symphony-plus"
    ]
  end

  defp releases do
    [
      symphony_plus: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm64: [os: :darwin, cpu: :aarch64],
            macos_x86_64: [os: :darwin, cpu: :x86_64],
            linux_arm64: [os: :linux, cpu: :aarch64],
            linux_x86_64: [os: :linux, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
