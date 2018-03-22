defmodule Blockchain.Transaction do
  @moduledoc """
  Represents one transaction within the chain.
  """

  # FIXME: because of the way they are defined, transactions are replayable
  @type t :: %Blockchain.Transaction{
          timestamp: integer,
          sender: Ed25519.key(),
          recipient: Ed25519.key(),
          amount: number,
          signature: Ed25519.signature()
        }

  defstruct timestamp: 0,
            sender: <<0::size(256)>>,
            recipient: <<0::size(256)>>,
            amount: 0.0,
            signature: <<0::size(512)>>

  def new(recipient, amount, priv)
      when amount >= 0 and (is_float(amount) or is_integer(amount)) and byte_size(priv) == 32 and
             byte_size(recipient) == 32 do
    sign(
      %__MODULE__{
        timestamp: System.system_time(:nanoseconds),
        sender: Ed25519.derive_public_key(priv),
        recipient: recipient,
        amount: amount / 1
      },
      priv
    )
  end

  def new(recipient, amount, priv) when is_bitstring(amount) do
    # Parse amount formatted as float or integers
    amount =
      cond do
        String.contains?(amount, ["e", "E"]) ->
          String.to_float(amount)

        # Add leading and closing zeros to parse things like ".5" or "1."
        String.contains?(amount, ".") ->
          String.to_float("0#{amount}0")

        true ->
          String.to_integer(amount)
      end

    new(recipient, amount, priv)
  end

  def new(recipient, amount, priv) when byte_size(priv) == 32 do
    new(Base.url_decode64!(recipient), amount, priv)
  end

  def new(recipient, amount, priv) do
    new(recipient, amount, Base.url_decode64!(priv))
  end

  @spec payload(transaction :: t()) :: binary
  def payload(%__MODULE__{
        timestamp: timestamp,
        sender: sender,
        recipient: recipient,
        amount: amount
      }) do
    <<timestamp::unsigned-little-integer-size(64)>> <> sender <> recipient <> <<amount::float>>
  end

  @spec sign(transaction :: t(), key :: Ed25519.key()) :: t()
  def sign(transaction, key) do
    signature = Ed25519.signature(payload(transaction), key, transaction.sender)
    %__MODULE__{transaction | signature: signature}
  end

  @spec valid?(transaction :: t()) :: boolean
  def valid?(%__MODULE__{sender: sender, amount: amount, signature: signature} = tx) do
    Ed25519.valid_signature?(signature, payload(tx), sender) and amount >= 0
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
