use Mix.Config

# Configure your database
config :blockchain, Blockchain.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "blockchain_dev",
  hostname: "localhost",
  pool_size: 10
