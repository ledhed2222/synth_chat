defmodule SupercolliderCubes.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SupercolliderCubesWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:supercollider_cubes, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SupercolliderCubes.PubSub},
      # Start SuperCollider command client (connects to Docker container)
      SupercolliderCubes.ScSynth,
      # Start the broadcaster, which is basically a multiplexer for sending
      # Start the audio room manager for WebRTC streaming
      SupercolliderCubes.AudioRoom,
      # Start to serve requests, typically the last entry
      SupercolliderCubesWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SupercolliderCubes.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SupercolliderCubesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
