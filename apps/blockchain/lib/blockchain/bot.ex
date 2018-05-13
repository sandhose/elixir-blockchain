defmodule Blockchain.Bot do
  use GenServer
  alias Blockchain.Transaction

  @opaque s() :: %{
            priv: term,
            pub: term,
            worker: pid,
            peers: MapSet.t()
          }

  @tx_cap 10.0

  def start_link(options) do
    options =
      options
      |> Keyword.put_new_lazy(:keypair, &Ed25519.generate_key_pair/0)
      |> Keyword.put_new(:worker, nil)

    GenServer.start_link(__MODULE__, options)
  end

  def init([worker: nil] = opts) do
    {:ok, worker} = Blockchain.Worker.start_link()
    Process.link(worker)
    init(Keyword.put(opts, :worker, worker))
  end

  def init(keypair: {priv, pub}, worker: worker) do
    Process.send_after(self(), :random_giveaway, 3000)

    {:ok,
     %{
       priv: priv,
       pub: pub,
       peers: MapSet.new(),
       worker: worker
     }}
  end

  def handle_info(:random_giveaway, %{priv: priv, pub: pub, worker: worker, peers: peers} = state) do
    unless Enum.empty?(peers) do
      balance = GenServer.call(worker, {:balance, pub}, 60000)
      amount = Float.round(:rand.uniform() * min(balance, @tx_cap), 3)

      unless amount < 0.001 do
        recipient = Enum.random(peers)
        tx = Transaction.new(recipient, amount, priv)
        GenServer.cast(worker, {:queue, tx})
      end
    end

    Process.send_after(self(), :random_giveaway, :rand.uniform(60000))

    {:noreply, state}
  end

  def handle_cast({:befriend, peer}, %{peers: peers} = state) do
    {:noreply, %{state | peers: MapSet.put(peers, peer)}}
  end

  def handle_call(:pub, _from, %{pub: pub} = state), do: {:reply, pub, state}
end
