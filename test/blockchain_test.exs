defmodule BlockchainTest do
  use ExUnit.Case
  doctest Blockchain

  alias Blockchain.{Block, Transaction}

  describe "Block.mine/1" do
    test "Should yield a valid block" do
      block = %Block{}
      mined = Block.mine(block)
      refute block == mined
      refute Block.valid?(block)
      assert Block.valid?(mined)
    end

    test "Mining a valid block should not alter it" do
      a = Block.mine(%Block{})
      b = Block.mine(a)

      assert a == b
    end
  end

  describe "Block.valid?/1" do
    test "A mined block should be valid" do
      assert Block.valid?(Block.mine(%Block{}))
    end

    test "Altering anything to a block should make it invalid" do
      block = Block.mine(%Block{parent: <<1, 2, 3>>})
      assert Block.valid?(block)
      refute Block.valid?(%Block{block | proof: block.proof + 1})
      refute Block.valid?(%Block{block | parent: <<3, 2, 1>>})
    end
  end

  describe "Block.hash/1" do
    test "Two identical blocks should have the same hash" do
      a = %Block{proof: 42}
      b = %Block{proof: 42}
      assert Block.hash(a) == Block.hash(b)
    end

    test "Two distinct blocks should have different hashes" do
      a = %Block{proof: 1}
      b = %Block{proof: 2}
      refute Block.hash(a) == Block.hash(b)
    end
  end

  describe "Transaction.new/3" do
    setup do
      {priv, pub} = Ed25519.generate_key_pair()
      {_, recipient} = Ed25519.generate_key_pair()
      {:ok, priv: priv, pub: pub, recipient: recipient}
    end

    test "Should have a valid timestamp", %{priv: priv, recipient: recipient} do
      time = System.system_time(:nanoseconds)
      tx = Transaction.new(recipient, 1, priv)
      assert_in_delta time, tx.timestamp, 1000 * 10
    end

    test "Should yield a valid transaction", %{priv: priv, pub: pub, recipient: recipient} do
      tx = Transaction.new(recipient, 1, priv)
      assert tx.sender == pub
      assert tx.amount == 1.0
      assert tx.recipient == recipient
      assert Ed25519.valid_signature?(tx.signature, Transaction.payload(tx), pub)
    end

    test "Should allow URL-friendly base64 strings as recipient", %{
      priv: priv,
      pub: pub,
      recipient: recipient
    } do
      tx = Transaction.new(Base.url_encode64(recipient), 1, priv)
      assert tx.sender == pub
      assert tx.amount == 1.0
      assert tx.recipient == recipient
      assert Ed25519.valid_signature?(tx.signature, Transaction.payload(tx), pub)
    end

    test "Should allow URL-friendly base64 strings as private key", %{
      priv: priv,
      pub: pub,
      recipient: recipient
    } do
      tx = Transaction.new(recipient, 1, Base.url_encode64(priv))
      assert tx.sender == pub
      assert tx.amount == 1.0
      assert tx.recipient == recipient
      assert Ed25519.valid_signature?(tx.signature, Transaction.payload(tx), pub)
    end

    test "Should allow strings as amount", %{priv: priv, recipient: rcpt} do
      for {source, target} <- [{"1", 1.0}, {"1.", 1.0}, {".5", 0.5}, {"1.5e-2", 0.015}] do
        assert %Transaction{amount: ^target} = Transaction.new(rcpt, source, priv)
      end
    end

    test "Should allow fancy input", %{priv: priv, pub: pub, recipient: rcpt} do
      tx =
        Transaction.new(
          Base.url_encode64(rcpt),
          "1.5",
          Base.url_encode64(priv)
        )

      assert tx.sender == pub
      assert tx.amount == 1.5
      assert tx.recipient == rcpt
      assert Ed25519.valid_signature?(tx.signature, Transaction.payload(tx), pub)
    end
  end

  describe "Transaction.sign/2" do
    setup do
      {priv, pub} = Ed25519.generate_key_pair()
      {:ok, priv: priv, pub: pub}
    end

    test "Should sign a transaction", %{priv: priv, pub: pub} do
      tx = Transaction.sign(%Transaction{sender: pub}, priv)

      assert Ed25519.valid_signature?(tx.signature, Transaction.payload(tx), pub)
    end
  end

  describe "Transaction.payload/1" do
    setup do
      {_, pub} = Ed25519.generate_key_pair()
      {:ok, pub: pub}
    end

    test "Should contain the timestamp" do
      timestamp = System.system_time(:nanoseconds)
      tx = %Transaction{timestamp: timestamp}

      assert String.contains?(
               Transaction.payload(tx),
               <<timestamp::unsigned-little-integer-size(64)>>
             )
    end

    test "Should contain the sender", %{pub: pub} do
      tx = %Transaction{sender: pub}
      assert String.contains?(Transaction.payload(tx), pub)
    end

    test "Should contain the recipient", %{pub: pub} do
      tx = %Transaction{recipient: pub}
      assert String.contains?(Transaction.payload(tx), pub)
    end

    test "Should contain the amount" do
      amount = 1.5
      tx = %Transaction{amount: amount}
      assert String.contains?(Transaction.payload(tx), <<amount::float>>)
    end

    test "Should not contain the signature" do
      # Fake signature
      sign = <<42::size(512)>>
      tx = %Transaction{signature: sign}

      refute String.contains?(Transaction.payload(tx), sign)
    end
  end

  describe "Transaction.hash/1" do
    test "Should accept an list or a single transaction" do
      tx = %Transaction{}
      assert Transaction.hash([tx]) == Transaction.hash(tx)
    end
  end

  describe "Transaction.valid?/1" do
    setup do
      {priv, pub} = Ed25519.generate_key_pair()
      {_, pub2} = Ed25519.generate_key_pair()
      {:ok, priv: priv, pub: pub, pub2: pub2}
    end

    test "Should validate transaction signature", %{priv: priv, pub: pub, pub2: pub2} do
      tx = %Transaction{sender: pub}
      signed = Transaction.sign(tx, priv)
      refute Transaction.valid?(tx)
      assert Transaction.valid?(signed)
      refute Transaction.valid?(%Transaction{signed | amount: 1.0})
      refute Transaction.valid?(%Transaction{signed | recipient: pub2})
      refute Transaction.valid?(%Transaction{signed | sender: pub2})
      refute Transaction.valid?(%Transaction{signed | timestamp: 42})
    end

    test "Should validate the transaction amount", %{priv: priv, pub: pub} do
      tx = %Transaction{sender: pub, amount: -1}
      signed = Transaction.sign(tx, priv)
      refute Transaction.valid?(signed)
    end
  end
end
