defmodule BlockchainWeb.Resolvers.Blocks do
  alias Blockchain.{Worker, Chain}

  def list(_parent, _args, _resolution) do
    head = Worker.head()
    limit = 4

    blocks =
      case Chain.lookup(head) do
        nil -> []
        block -> Enum.slice(block, 0, limit)
      end

    {:ok, blocks}
  end
end
