defmodule Blockchain.Block do
  @moduledoc """
  Represents one block within the blockchain.

  This module provides functions to hash blocks, validate proof, and find
  proofs (mine) for blocks.
  """

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

  @doc """
  Check if a block has a valid proof inside
  """
  @spec valid?(block :: t()) :: boolean
  def valid?(block) do
    challenge(hash(block), 16)
  end

  defp challenge(_hash, 0), do: true
  defp challenge(<<1::size(1), _::bitstring>>, _), do: false
  defp challenge(<<0::size(1), rest::bitstring>>, n), do: challenge(rest, n - 1)

  @doc """
  Find a valid proof for a given hash
  """
  def mine(block) do
    if valid?(block) do
      block
    else
      mine(%__MODULE__{block | proof: block.proof + 1})
    end
  end
end
