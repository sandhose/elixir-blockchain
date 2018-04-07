defmodule Blockchain.Block do
  @moduledoc """
  Represents one block within the blockchain.

  This module provides functions to hash blocks, validate proof, and find
  proofs (mine) for blocks.
  """

  require Logger

  alias Blockchain.Transaction

  @type t :: %Blockchain.Block{
          transactions: [Blockchain.Transaction.t()],
          nonce: p(),
          parent: h()
        }

  @typedoc "A block hash (SHA256)"
  @type h :: binary()

  @typedoc "Block nonce field"
  @type p :: integer

  defstruct transactions: [], nonce: 0, parent: ""

  @doc """
  Compute the hash of a block
  """
  @spec hash(block :: t()) :: h()
  def hash(block) do
    :crypto.hash_init(:sha256)
    |> Transaction.hash(block.transactions)
    |> :crypto.hash_update(<<block.nonce::little-unsigned-32>>)
    |> :crypto.hash_update(block.parent)
    |> :crypto.hash_final()
  end

  def valid?(block) do
    proof = valid_proof?(block)
    if not proof, do: Logger.warn("invalid proof")
    transactions = Enum.all?(block.transactions, &Transaction.valid?(&1))
    if not transactions, do: Logger.warn("invalid transactions")
    proof and transactions
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
end

defimpl String.Chars, for: Blockchain.Block do
  def to_string(%{transactions: txs, nonce: nonce, parent: parent} = block) do
    parent = Base.url_encode64(parent, padding: false)

    message =
      if nonce == 0 do
        ["Block"]
      else
        hash = Blockchain.Block.hash(block) |> Base.url_encode64(padding: false)
        ["Block #{hash}", "Nonce: #{nonce}"]
      end ++
        ["Parent: #{parent}"] ++
        if Enum.empty?(txs),
          do: ["No transaction"],
          else: ["Transactions:"] ++ Enum.map(txs, &"  #{&1}")

    Enum.join(message, "\n  ")
  end
end

# TODO: This implementation relies on Chain, which has to be initialized
defimpl Enumerable, for: Blockchain.Block do
  def count(_list), do: {:error, __MODULE__}
  def slice(_list), do: {:error, __MODULE__}
  def member?(_list, _value), do: {:error, __MODULE__}

  def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(list, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(list, &1, fun)}
  def reduce(%Blockchain.Block{parent: <<>>}, {:cont, acc}, _fun), do: {:done, acc}

  def reduce(block, {:cont, acc}, fun),
    do: reduce(Blockchain.Chain.lookup(block.parent), fun.(block, acc), fun)
end
