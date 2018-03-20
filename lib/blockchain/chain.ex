defmodule Blockchain.Chain do
  alias Blockchain.Block

  @type t :: [Blockchain.Block]

  def valid?(chain) do
    Enum.reduce_while(chain, "", fn block, parent ->
      if Block.valid?(block) && block.parent == parent do
        {:cont, Block.hash(block)}
      else
        {:halt, nil}
      end
    end) != nil
  end
end
