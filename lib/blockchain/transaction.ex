defmodule Blockchain.Transaction do
  @moduledoc """
  Represents one transaction within the chain.
  """

  # FIXME: because of the way they are defined, transactions are replayable
  @type t :: %Blockchain.Transaction{
          sender: Ed25519.key(),
          recipient: Ed25519.key(),
          amount: number,
          signature: Ed25519.signature() | nil
        }

  defstruct [:sender, :recipient, :amount, :signature]

  @spec payload(transaction :: t()) :: binary
  def payload(%__MODULE__{sender: sender, recipient: recipient, amount: amount}) do
    sender <> recipient <> <<amount::float>>
  end

  @spec sign(transaction :: t(), key :: Ed25519.key()) :: t()
  def sign(transaction, key) do
    signature = Ed25519.signature(payload(transaction), key, transaction.sender)
    %__MODULE__{transaction | signature: signature}
  end

  @spec valid?(transaction :: t()) :: boolean
  def valid?(transaction) do
    Ed25519.valid_signature?(transaction.signature, payload(transaction), transaction.sender)
  end

  def hash(t) do
    :crypto.hash_init(:sha256)
    |> hash(t)
    |> :crypto.hash_final()
  end

  def hash(sha, transactions) when is_list(transactions) do
    Enum.reduce(transactions, sha, fn t, sha -> hash(sha, t) end)
  end

  def hash(sha, transaction) do
    sha
    |> :crypto.hash_update(payload(transaction))
    |> :crypto.hash_update(transaction.signature)
  end
end

defimpl String.Chars, for: Blockchain.Transaction do
  def to_string(%{sender: snd, recipient: rcp, amount: amt, signature: sig}) do
    snd = Base.url_encode64(snd, padding: false)
    rcp = Base.url_encode64(rcp, padding: false)
    sig = Base.url_encode64(sig, padding: false)
    "#{snd} -#{amt}-> #{rcp} (sig: #{sig})"
  end
end
