use Mix.Config

# Configure your database
config :blockchain, Blockchain.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "blockchain_test",
  pool: Ecto.Adapters.SQL.Sandbox
