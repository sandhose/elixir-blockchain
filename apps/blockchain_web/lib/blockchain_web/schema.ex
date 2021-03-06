defmodule BlockchainWeb.Schema do
  use Absinthe.Schema
  use Absinthe.Relay.Schema, :modern

  import_types(BlockchainWeb.Schema.ContentTypes)

  alias Blockchain.{Chain, Block, Transaction}
  alias BlockchainWeb.Resolvers

  node interface do
    resolve_type(fn
      %Block{}, _ -> :block
      %Transaction{}, _ -> :transaction
      _, _ -> nil
    end)
  end

  query do
    node field do
      resolve(fn
        %{type: :block, id: id}, _ ->
          case Chain.lookup(BlockchainWeb.Application.chain(), id) do
            nil -> :error
            block -> {:ok, block}
          end

        %{type: :transaction, id: id}, _ ->
          case Chain.find_tx(BlockchainWeb.Application.chain(), id) do
            nil -> :error
            {tx, _} -> {:ok, tx}
          end
      end)
    end

    connection field(:blocks, node_type: :block, paginate: :forward) do
      resolve(&Resolvers.Blocks.list/3)
    end
  end
end
