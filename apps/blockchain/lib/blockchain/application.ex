defmodule Blockchain.Application do
  @moduledoc false

  use Application
  alias Blockchain.{Worker, Bot}

  def start(_type, _args) do
    {:ok, worker} = Worker.start_link(:ok)

    bots =
      for _ <- 1..10 do
        {:ok, pid} = Bot.start_link(worker: worker)
        pub = GenServer.call(pid, :pub)
        {pid, pub}
      end

    for {pid, _} <- bots,
        {pid2, pub} <- bots,
        pid != pid2 do
      GenServer.cast(pid, {:befriend, pub})
    end

    {_, pub} = Enum.at(bots, 0)
    GenServer.cast(worker, {:claim, pub})
    GenServer.cast(worker, :start)
    {:ok, worker}
  end
end
