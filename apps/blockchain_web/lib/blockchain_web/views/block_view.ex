defmodule BlockchainWeb.BlockView do
  use BlockchainWeb, :view

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

  def render("transaction.json", %{transaction: transaction}) do
    %{
      timestamp: transaction.timestamp,
      sender: Base.url_encode64(transaction.sender, padding: false),
      recipient: Base.url_encode64(transaction.recipient, padding: false),
      amount: transaction.amount,
      signature: Base.url_encode64(transaction.signature, padding: false)
    }
  end

  def render("block.json", %{block: block}) do
    %{
      transactions:
        render_many(
          block.transactions,
          BlockchainWeb.BlockView,
          "transaction.json",
          as: :transaction
        ),
      proof: block.proof,
      parent: Base.url_encode64(block.parent, padding: false)
    }
  end
end
