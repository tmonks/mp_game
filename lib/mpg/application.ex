defmodule MPG.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    maybe_run_migrations()

    children = [
      MPGWeb.Telemetry,
      MPG.Repo,
      {DNSCluster, query: Application.get_env(:mpg, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MPG.PubSub},
      # Start a worker by calling: MPG.Worker.start_link(arg)
      # {MPG.Worker, arg},
      # Start to serve requests, typically the last entry
      MPGWeb.Endpoint,
      {Registry, keys: :unique, name: MPG.GameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: MPG.GameSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MPG.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # In prod we migrate the SQLite analytics DB at boot rather than via Fly's
  # release_command, since that runs on a separate machine without the volume.
  defp maybe_run_migrations do
    if Application.get_env(:mpg, :run_migrations_on_boot, false) do
      MPG.Release.migrate()
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MPGWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
