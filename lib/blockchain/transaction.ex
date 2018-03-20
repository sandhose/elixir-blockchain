defmodule Blockchain.Transaction do
  @moduledoc """
  Represents one transaction within the chain.
  """

  @type t :: %Blockchain.Transaction{
          sender: term,
          recipient: term,
          amount: number
        }

  @derive [Poison.Encoder]

  defstruct [:sender, :recipient, :amount]
end
