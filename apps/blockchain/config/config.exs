use Mix.Config

config :blockchain, ecto_repos: [Blockchain.Repo]

import_config "#{Mix.env()}.exs"
