require Logger
alias Blockchain.{Worker, Bot}

# Create the worker
{:ok, worker} = Worker.start_link(name: Worker)

# Create 10 bots
bots =
  for _ <- 1..10 do
    {:ok, pid} = Bot.start_link(worker: worker)
    pub = GenServer.call(pid, :pub)
    {pid, pub}
  end

# …and make them discover each others
for {pid, _} <- bots,
    {pid2, pub} <- bots,
    pid != pid2 do
  GenServer.cast(pid, {:befriend, pub})
end

# Claim the worker to the first bot
{_, pub} = Enum.at(bots, 0)
GenServer.cast(worker, {:claim, pub})

# Connect to other nodes
for arg <- System.argv() do
  remote = String.to_atom(arg)

  if Node.connect(remote) do
    GenServer.cast(worker, {:add_peer, {Worker, remote}})
  else
    Logger.warn("Could not connect to #{arg}")
  end
end

# Start the worker
GenServer.cast(worker, :start)

# Continue until the worker crashes
ref = Process.monitor(worker)

receive do
  {:DOWN, ^ref, _, _, _} ->
    IO.puts("Worker is down!")
end
