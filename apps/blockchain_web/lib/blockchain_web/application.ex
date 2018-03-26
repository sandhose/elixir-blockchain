defmodule BlockchainWeb.Application do
  use Application

  def start(_type, _args) do
    children = [
      BlockchainWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BlockchainWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BlockchainWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
