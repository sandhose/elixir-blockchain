use Mix.Config

# Configure your database
config :blockchain, Blockchain.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "blockchain_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
