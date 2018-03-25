use Mix.Config

# Configure your database
config :blockchain, Blockchain.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "blockchain_dev",
  hostname: "localhost",
  pool_size: 10
