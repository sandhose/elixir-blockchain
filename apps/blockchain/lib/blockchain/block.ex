defmodule Blockchain.Block do
  @moduledoc """
  Represents one block within the blockchain.

  This module provides functions to hash blocks, validate proof, and find
  proofs (mine) for blocks.
  """

  require Logger

  alias Blockchain.{Transaction, Chain}

  @type t() :: %Blockchain.Block{
          index: integer,
          transactions: [Blockchain.Transaction.t()],
          tx_hash: h() | nil,
          nonce: p(),
          parent: h()
        }

  @typedoc "A block hash (SHA256)"
  @type h :: binary()

  @typedoc "Block nonce field"
  @type p :: integer

  defstruct index: 0, transactions: [], nonce: 0, parent: "", tx_hash: nil

  @doc """
  Compute the hash of a block
  """
  @spec hash(block :: t()) :: h()
  def hash(%__MODULE__{tx_hash: nil} = block), do: hash(optimize(block))

  def hash(block) do
    :crypto.hash_init(:sha256)
    |> :crypto.hash_update(<<block.index::little-unsigned-32>>)
    |> :crypto.hash_update(block.tx_hash)
    |> :crypto.hash_update(<<block.nonce::little-unsigned-32>>)
    |> :crypto.hash_update(block.parent)
    |> :crypto.hash_final()
  end

  @doc """
  Optimize a block by saving the transaction hash inside it
  """
  @spec optimize(block :: t()) :: t()
  def optimize(block) do
    %__MODULE__{block | tx_hash: Transaction.hash(block.transactions)}
  end

  @doc """
  Check if a block is valid
  """
  @spec valid?(block :: t()) :: boolean
  def valid?(block) do
    proof = valid_proof?(block)
    if not proof, do: Logger.warn("invalid proof")

    optimized = block.tx_hash == nil or block == optimize(block)
    if not optimized, do: Logger.warn("tx optimization was wrong")

    transactions = Enum.all?(block.transactions, &Transaction.valid?(&1))
    if not transactions, do: Logger.warn("invalid transactions")

    proof and transactions and optimized
  end

  @doc """
  Check if a block has a valid proof inside
  """
  @spec valid_proof?(block :: t()) :: boolean
  def valid_proof?(block) do
    challenge(hash(block), 16)
  end

  defp challenge(_hash, 0), do: true
  defp challenge(<<1::size(1), _::bitstring>>, _), do: false
  defp challenge(<<0::size(1), rest::bitstring>>, n), do: challenge(rest, n - 1)

  @doc """
  Find a valid proof for a given hash
  """
  def mine(block) do
    if valid_proof?(block) do
      block
    else
      mine(%__MODULE__{block | nonce: block.nonce + 1})
    end
  end

  defmodule Enum do
    @moduledoc """
    Simple wrapper module to iterate through a Chain

    It's ugly, don't look at that.
    """

    alias Blockchain.Block

    @enforce_keys [:head, :chain]
    defstruct [:head, :chain]

    @opaque t() :: %__MODULE__{head: Block.t(), chain: Chain.t()}

    @spec new(head :: Block.h() | Block.t(), chain :: Chain.t()) :: Blockchain.Block.Enum.t()
    def new(head, chain) when is_binary(head),
      do: new(Chain.lookup(chain, head), chain)

    def new(%Block{} = head, %Chain{} = chain),
      do: %__MODULE__{head: head, chain: chain}

    def next(%__MODULE__{chain: nil}), do: nil
    def next(%__MODULE__{head: nil}), do: nil

    def next(%__MODULE__{head: head, chain: chain} = enum),
      do: %__MODULE__{enum | head: Chain.lookup(chain, head.parent)}
  end

  defimpl Enumerable, for: Block.Enum do
    def count(_list), do: {:error, __MODULE__}
    def slice(_list), do: {:error, __MODULE__}
    def member?(_list, _value), do: {:error, __MODULE__}

    def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
    def reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(list, &1, fun)}
    def reduce(%Blockchain.Block.Enum{head: nil}, {:cont, acc}, _fun), do: {:done, acc}

    def reduce(enum, {:cont, acc}, fun),
      do: reduce(Enum.next(enum), fun.(enum.head, acc), fun)
  end
end

defimpl String.Chars, for: Blockchain.Block do
  def to_string(%{index: index, transactions: txs, nonce: nonce, parent: parent} = block) do
    parent = Base.url_encode64(parent, padding: false)

    message =
      if nonce == 0 do
        ["Block ##{index}"]
      else
        hash = Blockchain.Block.hash(block) |> Base.url_encode64(padding: false)
        ["Block ##{index} #{hash}", "Nonce: #{nonce}"]
      end ++
        ["Parent: #{parent}"] ++
        if Enum.empty?(txs),
          do: ["No transaction"],
          else: ["Transactions:"] ++ Enum.map(txs, &"  #{&1}")

    Enum.join(message, "\n  ")
  end
end
