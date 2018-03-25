defmodule Blockchain.Transaction do
  @moduledoc """
  Represents one transaction within the chain.
  """

  @reward 1.0
  @rewarder <<0::size(256)>>

  @type t :: %__MODULE__{
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

  @spec new(
          recipient :: Ed25519.key() | String.t(),
          amount :: float | integer | String.t(),
          priv :: Ed25519.key() | String.t()
        ) :: t()
  def new(recipient, amount, priv)
      when amount >= 0 and is_float(amount) and byte_size(priv) == 32 and
             byte_size(recipient) == 32 do
    sign(
      %__MODULE__{
        timestamp: System.system_time(:nanoseconds),
        sender: Ed25519.derive_public_key(priv),
        recipient: recipient,
        amount: amount
      },
      priv
    )
  end

  def new(recipient, amount, priv) when is_integer(amount) do
    new(recipient, amount / 1, priv)
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
    is_reward?(tx) or (Ed25519.valid_signature?(signature, payload(tx), sender) and amount >= 0)
  end

  def reward(recipient) do
    %__MODULE__{
      timestamp: System.system_time(:nanoseconds),
      sender: @rewarder,
      recipient: recipient,
      amount: @reward
    }
  end

  def is_reward?(tx) do
    tx.sender == @rewarder and tx.amount == @reward
  end

  defp prune_accounts(accounts) do
    Map.drop(accounts, for({acc, amount} <- accounts, amount == 0.0, do: acc))
  end

  @spec run(
          accounts :: %{binary() => float()},
          hashes :: MapSet.t(binary()),
          transactions :: [t()]
        ) :: {:ok, %{binary() => float()}, MapSet.t(binary())} | {:error, t()}
  def run(accounts, hashes, []), do: {:ok, prune_accounts(accounts), hashes}

  def run(accounts, hashes, [tx | transactions]) do
    hash = hash(tx)

    cond do
      MapSet.member?(hashes, hash) ->
        {:error, tx}

      not valid?(tx) ->
        {:error, tx}

      is_reward?(tx) ->
        accounts = Map.update(accounts, tx.recipient, tx.amount, &(&1 + tx.amount))
        hashes = MapSet.put(hashes, hash)
        run(accounts, hashes, transactions)

      tx.amount <= Map.get(accounts, tx.sender, 0.0) ->
        accounts = Map.update(accounts, tx.recipient, tx.amount, &(&1 + tx.amount))
        accounts = Map.update(accounts, tx.sender, 0.0, &(&1 - tx.amount))
        hashes = MapSet.put(hashes, hash)
        run(accounts, hashes, transactions)

      true ->
        {:error, tx}
    end
  end

  @spec rollback(
          accounts :: %{binary() => float()},
          hashes :: MapSet.t(binary()),
          transactions :: [t()]
        ) :: {:ok, %{binary() => float()}, MapSet.t(binary())} | {:error, t()}
  def rollback(accounts, hashes, []), do: {:ok, prune_accounts(accounts), hashes}

  def rollback(accounts, hashes, [tx | transactions]) do
    hash = hash(tx)

    cond do
      not valid?(tx) ->
        {:error, tx}

      MapSet.member?(hashes, hash) and tx.amount <= Map.get(accounts, tx.recipient, 0.0) ->
        accounts = Map.update(accounts, tx.recipient, tx.amount, &(&1 - tx.amount))

        accounts =
          if is_reward?(tx),
            do: accounts,
            else: Map.update(accounts, tx.sender, 0.0, &(&1 + tx.amount))

        hashes = MapSet.delete(hashes, hash)
        rollback(accounts, hashes, transactions)

      true ->
        {:error, tx}
    end
  end

  @spec hash(tx :: t() | [t()]) :: binary()
  def hash(tx) do
    :crypto.hash_init(:sha256)
    |> hash(tx)
    |> :crypto.hash_final()
  end

  @spec hash(sha :: term(), tx :: t() | [t()]) :: term()
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
  def to_string(%{sender: snd, recipient: rcp, amount: amt, signature: sig, timestamp: ts} = tx) do
    [snd, rcp, sig] = Enum.map([snd, rcp, sig], &Base.url_encode64(&1, padding: false))
    date = DateTime.from_unix!(ts, :nanoseconds)

    if Blockchain.Transaction.is_reward?(tx) do
      "#{date}: REWARD -(#{amt})-> #{rcp}"
    else
      "#{date}: #{snd} -(#{amt})-> #{rcp} (sig: #{sig})"
    end
  end
end
