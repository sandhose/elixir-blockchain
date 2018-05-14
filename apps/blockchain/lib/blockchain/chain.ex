defmodule Blockchain.Chain do
  alias Blockchain.{Block, Transaction}
  require Logger

  @type t() :: %__MODULE__{blocks: term(), transactions: term()}

  defstruct [:blocks, :transactions]

  @spec lookup(chain :: t(), hash :: Block.h()) :: Block.t() | nil
  def lookup(_chain, <<>>), do: nil

  def lookup(chain, hash) do
    case :ets.lookup(chain.blocks, hash) do
      [{_hash, block}] -> block
      _ -> nil
    end
  end

  @spec find_tx(chain :: t(), hash :: binary()) :: {Transaction.t(), Block.h()} | nil
  def find_tx(chain, hash) do
    case :ets.lookup(chain.transactions, hash) do
      [{_hash, tx, block_hash}] -> {tx, block_hash}
      _ -> nil
    end
  end

  @spec insert(chain :: t(), block :: Block.t()) :: :ok | :error
  def insert(chain, block) do
    if Block.valid?(block) do
      hash = Block.hash(block)
      :ets.insert(chain.blocks, {hash, block})
      txs = Enum.map(block.transactions, fn tx -> {Transaction.hash(tx), tx, hash} end)
      :ets.insert(chain.transactions, txs)
      :ok
    else
      :error
    end
  end

  @spec new :: t()
  def new do
    %__MODULE__{
      blocks: :ets.new(nil, [:set, :protected]),
      transactions: :ets.new(nil, [:set, :protected])
    }
  end

  @spec valid?(chain :: t(), block :: Block.t() | nil) :: boolean
  def valid?(_chain, nil), do: false

  def valid?(chain, block) do
    cond do
      not Block.valid?(block) ->
        false

      block.parent == <<>> ->
        block.index == 0

      true ->
        parent = lookup(chain, block.parent)

        unless parent == nil do
          parent.index + 1 == block.index && valid?(chain, parent)
        else
          false
        end
    end
  end
end
