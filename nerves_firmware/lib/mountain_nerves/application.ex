defmodule MountainNerves.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    target = Nerves.Runtime.mix_target()
    kv = if target != :host, do: Nerves.Runtime.KV.get_all(), else: %{}
    setup_bot(kv)
    setup_wifi(kv)
    setup_database()

    children =
      [
        # Children for all targets
        # Starts a worker by calling: MountainNerves.Worker.start_link(arg)
        # {MountainNerves.Worker, arg},
      ] ++ target_children(target)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MountainNerves.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  defp target_children(:host) do
    [
      MountainNerves.Repo,
      InterfaceWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:mountain_nerves, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Interface.PubSub},
      InterfaceWeb.Endpoint,
      ExGram,
      {MountainNerves.Bot, [method: :polling, token: Application.get_env(:ex_gram, :token)]}
    ]
  end

  defp target_children(_target) do
    wifi_enabled = Application.get_env(:mountain_nerves, :wifi_enabled, false)

    wifi_child = if wifi_enabled, do: [{MountainNerves.WiFi, []}], else: []

    [
      MountainNerves.Repo
    ] ++
      wifi_child ++
      [
        InterfaceWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:mountain_nerves, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Interface.PubSub},
        InterfaceWeb.Endpoint,
        {MountainNerves.LCD1602, [bus: "i2c-1", address: 0x27]},
        ExGram,
        {MountainNerves.Bot, [method: :polling, token: Application.get_env(:ex_gram, :token)]}
      ]
  end

  if Mix.target() == :host do
    defp setup_bot(_kv), do: :ok
    defp setup_wifi(_kv), do: :ok
    defp setup_database(), do: :ok
  else
    defp setup_bot(kv) do
      token = kv["bot_token"]
      tg_owner_user = kv["tg_owner_user"]

      if token && token != "" do
        Application.put_env(:ex_gram, :token, token)
      end

      if tg_owner_user && tg_owner_user != "" do
        Application.put_env(:mountain_nerves, :tg_owner_user, tg_owner_user)
      end
    end

    defp setup_wifi(kv) do
      wifi_enabled = kv["wifi_enabled"]

      if wifi_enabled && wifi_enabled != "" do
        Application.put_env(:mountain_nerves, :wifi_enabled, true)
      else
        Application.put_env(:mountain_nerves, :wifi_enabled, false)
      end
    end

    defp setup_database() do
      MountainNerves.Release.migrate()
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    InterfaceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
