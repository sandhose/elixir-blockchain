defmodule BlockchainWeb.Resolvers.Blocks do
  alias Blockchain.{Worker, Chain, Block}

  @doc """
  Connection-like resolver for blocks
  """
  def list(_parent, args, _resolution) do
    # Fetch the cursor and the limit frop arguments
    # If no `after` was set, use the chain's head
    cursor =
      Map.get_lazy(args, :after, fn ->
        BlockchainWeb.Application.head() |> Base.url_encode64(padding: false)
      end)
      |> Base.url_decode64(padding: false)

    limit = Map.get(args, :first, 10)

    # Check for cursor validity
    case cursor do
      :error ->
        {:error, message: "Invalid cursor"}

      {:ok, cursor} ->
        # Lookup for the head block
        block = Chain.lookup(BlockchainWeb.Application.chain(), cursor)

        if block == nil do
          {:error, message: "Block not found"}
        else
          # Construct the edges, with their cursor
          edges =
            Enum.slice(block, 0, limit)
            |> Enum.map(fn block ->
              %{cursor: Block.hash(block) |> Base.url_encode64(padding: false), node: block}
            end)

          # Build page informations
          page_info = %{
            start_cursor: List.first(edges).cursor,
            end_cursor: List.last(edges).cursor,
            has_previous_page: false,
            has_next_page: List.last(edges).node.parent != nil
          }

          {:ok, %{edges: edges, page_info: page_info}}
        end
    end
  end
end
