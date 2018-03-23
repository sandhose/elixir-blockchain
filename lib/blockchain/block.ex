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
          proof: p(),
          parent: h()
        }

  @typedoc "A block hash (SHA256)"
  @type h :: binary()

  @typedoc "Block proof"
  @type p :: integer

  defstruct transactions: [], proof: 0, parent: ""

  @doc """
  Compute the hash of a block
  """
  @spec hash(block :: t()) :: h()
  def hash(block) do
    :crypto.hash_init(:sha256)
    |> Transaction.hash(block.transactions)
    |> :crypto.hash_update(<<block.proof::little-unsigned-32>>)
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
      mine(%__MODULE__{block | proof: block.proof + 1})
    end
  end
end

defimpl String.Chars, for: Blockchain.Block do
  def to_string(%{transactions: txs, proof: proof, parent: parent} = block) do
    parent = Base.url_encode64(parent, padding: false)

    message =
      if proof == 0 do
        ["Block"]
      else
        hash = Blockchain.Block.hash(block) |> Base.url_encode64(padding: false)
        ["Block #{hash}", "Proof: #{proof}"]
      end ++
        ["Parent: #{parent}"] ++
        if Enum.empty?(txs),
          do: ["No transaction"],
          else: ["Transactions:"] ++ Enum.map(txs, &"  #{&1}")

    Enum.join(message, "\n  ")
  end
end
