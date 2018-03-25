defmodule BlockchainWeb.PageController do
  use BlockchainWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
