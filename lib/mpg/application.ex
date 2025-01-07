defmodule MPG.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MPGWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:mpg, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MPG.PubSub},
      # Start a worker by calling: MPG.Worker.start_link(arg)
      # {MPG.Worker, arg},
      # Start to serve requests, typically the last entry
      MPGWeb.Endpoint,
      {MPG.Things.Session, name: :things_session},
      {MPG.Quizzes.Session, name: :quiz_session}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MPG.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MPGWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
