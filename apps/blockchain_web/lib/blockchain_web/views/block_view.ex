defmodule BlockchainWeb.BlockView do
  require Logger
  use BlockchainWeb, :view

  defp encode_or_nil(binary) do
    len = byte_size(binary) * 8

    if binary == <<0::size(len)>>,
      do: nil,
      else: Base.url_encode64(binary, padding: false)
  end

  def render("index.json", %{blocks: blocks}) do
    %{data: render_many(blocks, BlockchainWeb.BlockView, "block.json")}
  end

  def render("transactions.json", %{transactions: transactions}) do
    render_many(
      transactions,
      BlockchainWeb.BlockView,
      "transaction.json",
      as: :transaction
    )
  end

  def render("transaction.json", %{
        transaction: %Blockchain.Transaction{
          timestamp: timestamp,
          sender: sender,
          recipient: recipient,
          amount: amount,
          signature: signature
        }
      }) do
    %{
      timestamp: timestamp,
      sender: encode_or_nil(sender),
      recipient: encode_or_nil(recipient),
      amount: amount,
      signature: encode_or_nil(signature)
    }
  end

  def render("block.json", %{
        block:
          %Blockchain.Block{
            index: index,
            transactions: transactions,
            nonce: nonce,
            parent: parent
          } = block
      }) do
    %{
      index: index,
      hash: Blockchain.Block.hash(block) |> encode_or_nil,
      transactions:
        render_many(
          transactions,
          BlockchainWeb.BlockView,
          "transaction.json",
          as: :transaction
        ),
      nonce: nonce,
      parent: encode_or_nil(parent)
    }
  end
end
