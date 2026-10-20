import Config

config :phoenix, :json_library, Jason

config :symphony_plus, SymphonyPlusWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: SymphonyPlusWeb.ErrorHTML, json: SymphonyPlusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SymphonyPlus.PubSub,
  live_view: [signing_salt: "symphony-plus-live-view"],
  secret_key_base: String.duplicate("s", 64),
  check_origin: false,
  server: false

if config_env() == :test do
  config :symphony_plus,
    workflow_file_path: Path.expand("../test/fixtures/startup_workflow.md", __DIR__)
end
