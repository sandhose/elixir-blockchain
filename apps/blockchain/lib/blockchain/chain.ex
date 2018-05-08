defmodule Blockchain.Chain do
  alias Blockchain.{Block, Transaction}
  require Logger

  @blocks :blocks
  @transactions :transactions

  def lookup(<<>>), do: nil

  def lookup(hash) do
    case :ets.lookup(@blocks, hash) do
      [{_hash, block}] -> block
      _ -> nil
    end
  end

  @spec find_tx(hash :: binary()) :: {Transaction.t(), Block.h()} | nil
  def find_tx(hash) do
    case :ets.lookup(@transactions, hash) do
      [{_hash, tx, block_hash}] -> {tx, block_hash}
      _ -> nil
    end
  end

  def insert(block) do
    if Block.valid?(block) do
      hash = Block.hash(block)
      :ets.insert(@blocks, {hash, block})
      txs = Enum.map(block.transactions, fn tx -> {Transaction.hash(tx), tx, hash} end)
      :ets.insert(@transactions, txs)
      :ok
    else
      :error
    end
  end

  def init do
    :ets.new(@blocks, [:set, :protected, :named_table])
    :ets.new(@transactions, [:set, :protected, :named_table])
  end

  def valid?(nil), do: false

  def valid?(block) do
    cond do
      not Block.valid?(block) ->
        false

      block.parent == <<>> ->
        block.index == 0

      true ->
        parent = lookup(block.parent)

        unless parent == nil do
          parent.index + 1 == block.index && valid?(parent)
        else
          false
        end
    end
  end
end
