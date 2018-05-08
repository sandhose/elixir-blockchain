defmodule BlockchainWeb.Schema do
  use Absinthe.Schema
  import_types(BlockchainWeb.Schema.ContentTypes)

  alias BlockchainWeb.Resolvers

  query do
    field :blocks, list_of(:block) do
      resolve(&Resolvers.Blocks.list/3)
    end
  end
end
