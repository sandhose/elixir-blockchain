defmodule BlockchainWeb.Schema.ContentTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  scalar :hash, name: "Hash" do
    serialize(&Base.url_encode64(&1, padding: false))
    parse(&parse_hash/1)
  end

  @spec parse_hash(Absinthe.Blueprint.Input.String.t()) :: {:ok, binary} | :error
  @spec parse_hash(Absinthe.Blueprint.Input.Null.t()) :: {:ok, nil}
  defp parse_hash(%Absinthe.Blueprint.Input.String{value: value}) do
    Base.url_decode64(value, padding: false)
  end

  defp parse_hash(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp parse_hash(_) do
    :error
  end

  defp tx_id(%Blockchain.Transaction{} = tx, _), do: Blockchain.Transaction.hash(tx)
  defp tx_id(_, _), do: nil

  node object(:transaction, id_fetcher: &tx_id/2) do
    field(:timestamp, :integer)
    field(:sender, :hash)
    field(:recipient, :hash)
    field(:amount, :float)
    field(:signature, :hash)
  end

  connection(node_type: :transaction)

  defp block_id(%Blockchain.Block{} = block, _), do: Blockchain.Block.hash(block)
  defp block_id(_, _), do: nil

  node object(:block, id_fetcher: &block_id/2) do
    field(:index, :integer)

    connection field(:transactions, node_type: :transaction) do
      resolve(fn pagination_args, %{source: block} ->
        Absinthe.Relay.Connection.from_list(
          block.transactions,
          pagination_args
        )
      end)
    end

    field(:nonce, :integer)
    field(:parent, :hash)
  end

  connection(node_type: :block)
end
