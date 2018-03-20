defmodule Blockchain.Block do
  @moduledoc """
  Represents one block within the blockchain.

  This module provides functions to hash blocks, validate proof, and find
  proofs (mine) for blocks.
  """

  @type t :: %Blockchain.Block{
          index: integer,
          timestamp: term,
          transactions: [Blockchain.Transaction.t()],
          proof: term,
          parent: term
        }

  @typedoc "A block hash (SHA256)"
  @type h :: String.t()

  @typedoc "Block proof"
  @type p :: integer

  @derive [Poison.Encoder]

  defstruct [:index, :timestamp, :transactions, :proof, :parent]

  @doc """
  Check if a given proof is valid for a given hash
  """
  @spec valid_proof?(proof :: p(), hash :: h()) :: bool
  def valid_proof?(proof, hash) do
    hash =
      :crypto.hash_init(:sha256)
      |> :crypto.hash_update(<<proof::little-unsigned-32>>)
      |> :crypto.hash_update(Base.decode16!(String.upcase(hash)))
      |> :crypto.hash_final()

    match?(<<0, 0, 0, _::binary>>, hash)
  end

  @doc """
  Find a valid proof for a given hash
  """
  @spec mine(block :: t()) :: p()
  def mine(block) do
    find_proof(hash(block), 0)
  end

  defp find_proof(hash, proof) do
    if valid_proof?(proof, hash), do: proof, else: find_proof(hash, proof + 1)
  end

  @doc """
  Compute the hash of a block
  """
  @spec hash(block :: t()) :: h()
  def hash(block) do
    :crypto.hash(:sha256, Poison.encode!(block))
    |> Base.encode16()
    |> String.downcase()
  end
end
