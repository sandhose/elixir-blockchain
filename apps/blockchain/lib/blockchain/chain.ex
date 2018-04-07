defmodule Blockchain.Chain do
  alias Blockchain.Block
  require Logger

  @table :blocks

  def lookup(<<>>), do: nil

  def lookup(hash) do
    case :ets.lookup(@table, hash) do
      [{_hash, block}] -> block
      _ -> nil
    end
  end

  def insert(block) do
    if Block.valid?(block) do
      :ets.insert(@table, {Block.hash(block), block})
      :ok
    else
      :error
    end
  end

  def init do
    :ets.new(@table, [:set, :protected, :named_table])
  end

  def valid?(nil), do: false

  def valid?(block) do
    cond do
      not Block.valid?(block) -> false
      block.parent == <<>> -> true
      true -> valid?(lookup(block.parent))
    end
  end
end
