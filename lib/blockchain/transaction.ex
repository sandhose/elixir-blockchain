defmodule Blockchain.Transaction do
  @moduledoc """
  Represents one transaction within the chain.
  """

  @type t :: %Blockchain.Transaction{
          sender: binary,
          recipient: binary,
          amount: number
        }

  defstruct [:sender, :recipient, :amount]

  def hash(t) do
    :crypto.hash_init(:sha256)
    |> hash(t)
    |> :crypto.hash_final()
  end

  def hash(sha, transactions) when is_list(transactions) do
    Enum.reduce(transactions, sha, fn t, sha -> hash(sha, t) end)
  end

  def hash(sha, %__MODULE__{sender: sender, recipient: recipient, amount: amount}) do
    sha
    |> :crypto.hash_update(sender)
    |> :crypto.hash_update(recipient)
    |> :crypto.hash_update(<<amount::float>>)
  end
end
