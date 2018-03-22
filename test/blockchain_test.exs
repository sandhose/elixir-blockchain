defmodule BlockchainTest do
  use ExUnit.Case
  doctest Blockchain

  alias Blockchain.Block

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
end
