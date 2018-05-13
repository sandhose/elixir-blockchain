defmodule BlockchainWeb.Application do
  use Application

  alias Blockchain.Worker

  @worker_name WebWorker

  @doc """
  Get the application-wide worker's head
  """
  def head, do: Worker.head(@worker_name)

  @doc """
  Get the application-wide worker's chain
  """
  def chain, do: Worker.chain(@worker_name)

  def start(_type, _args) do
    children = [
      {Worker, name: @worker_name},
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
