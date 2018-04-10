defmodule BlockchainWeb.BlockController do
  require Logger
  use BlockchainWeb, :controller

  alias Blockchain.{Worker, Chain}

  def block_from_param(nil), do: nil

  def block_from_param(hash) do
    case Base.url_decode64(hash, padding: false) do
      {:ok, hash} -> Chain.lookup(hash)
      :error -> nil
    end
  end

  def index(conn, params) do
    head =
      Map.get_lazy(params, :head, fn ->
        Worker.head() |> Base.url_encode64(padding: false)
      end)

    limit = Map.get(params, :first, 5) - 1

    blocks =
      case block_from_param(head) do
        nil -> []
        block -> Enum.slice(block, 0, limit)
      end

    render(conn, "index.json", blocks: blocks)
  end

  def show(conn, %{"hash" => hash}) do
    case block_from_param(hash) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(BlockchainWeb.ErrorView)
        |> render(:"404")

      block ->
        render(conn, "block.json", block: block)
    end
  end

  def transactions(conn, %{"hash" => hash}) do
    case block_from_param(hash) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(BlockchainWeb.ErrorView)
        |> render(:"404")

      block ->
        render(conn, "transactions.json", transactions: block.transactions)
    end
  end
end
