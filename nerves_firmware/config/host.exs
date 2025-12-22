import Config

# Add configuration that is only needed when running on the host here.

config :nerves_runtime,
  kv_backend:
    {Nerves.Runtime.KVBackend.InMemory,
     contents: %{
       # The KV store on Nerves systems is typically read from UBoot-env, but
       # this allows us to use a pre-populated InMemory store when running on
       # host for development and testing.
       #
       # https://hexdocs.pm/nerves_runtime/readme.html#using-nerves_runtime-in-tests
       # https://hexdocs.pm/nerves_runtime/readme.html#nerves-system-and-firmware-metadata

       "nerves_fw_active" => "a",
       "a.nerves_fw_architecture" => "generic",
       "a.nerves_fw_description" => "N/A",
       "a.nerves_fw_platform" => "host",
       "a.nerves_fw_version" => "0.0.0"
     }}

# Configure Ecto for host environment
if Mix.env() == :test do
  config :mountain_nerves, MountainNerves.Repo,
    database: Path.expand("../mountain_nerves_test.db", Path.dirname(__ENV__.file)),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  # Disable the endpoint server in tests
  config :mountain_nerves, InterfaceWeb.Endpoint, server: false

  # Print only warnings and errors during test
  config :logger, level: :warning
else
  config :mountain_nerves, MountainNerves.Repo,
    database: Path.expand("../mountain_nerves_dev.db", Path.dirname(__ENV__.file)),
    pool_size: 5,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
end

# Configure ExGram adapter
config :ex_gram, adapter: ExGram.Adapter.Req, json_engine: Jason, delete_webhook: true
