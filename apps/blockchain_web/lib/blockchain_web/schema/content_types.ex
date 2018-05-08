defmodule BlockchainWeb.Schema.ContentTypes do
  use Absinthe.Schema.Notation

  scalar :hash, name: "Hash" do
    serialize(&Base.url_encode64(&1, padding: false))
    parse(&parse_hash/1)
  end

  @spec parse_hash(Absinthe.Blueprint.Input.String.t()) :: {:ok, binary} | :error
  @spec parse_hash(Absinthe.Blueprint.Input.Null.t()) :: {:ok, nil}
  defp parse_hash(%Absinthe.Blueprint.Input.String{value: value}) do
    Base.url_decode64(value, padding: false)
  end

  defp parse_hash(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp parse_hash(_) do
    :error
  end

  object :transaction do
    field(:timestamp, :integer)
    field(:sender, :hash)
    field(:recipient, :hash)
    field(:amount, :float)
    field(:signature, :hash)
  end

  object :block do
    field(:index, :integer)
    field(:transactions, list_of(:transaction))
    field(:nonce, :integer)
    field(:parent, :hash)
  end
end
