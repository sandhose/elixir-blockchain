defmodule Blockchain.Worker do
  use GenServer
  require Logger

  alias Blockchain.{Block, Chain, Transaction}

  @type accounts() :: %{Ed25519.key() => float}
  @type tx_hashes() :: MapSet.t(binary())

  @type t() :: %{
          chain: Chain.t(),
          pending: MapSet.t(Transaction.t()),
          head: Block.h(),
          timer: reference() | nil,
          accounts: accounts(),
          tx_hashes: tx_hashes(),
          reward_to: Ed25519.key() | nil,
          task: pid() | nil,
          peers: MapSet.t(term())
        }

  def start_link(opts \\ []) do
    # TODO: worker name is temporary
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def head(wrk), do: GenServer.call(wrk, :head)
  def chain(wrk), do: GenServer.call(wrk, :chain)

  @spec init(:ok) :: {:ok, t()}
  def init(:ok) do
    {:ok,
     %{
       chain: Chain.new(),
       pending: MapSet.new(),
       head: <<>>,
       timer: nil,
       accounts: %{},
       tx_hashes: MapSet.new(),
       reward_to: nil,
       task: nil,
       peers: MapSet.new()
     }}
  end

  defp next_index(_chain, <<>>), do: 0
  defp next_index(chain, hash), do: Chain.lookup(chain, hash).index + 1

  @doc """
  Get the difference between two blocks in a chain
  """
  def diff(from, to, _chain) when from == to do
    {[], []}
  end

  def diff(nil, %Block{parent: parent} = to, chain) do
    {added, removed} = diff(nil, Chain.lookup(chain, parent), chain)
    {added ++ [to], removed}
  end

  def diff(%Block{index: i, parent: parent} = from, %Block{index: j} = to, chain) when i > j do
    {added, removed} = diff(Chain.lookup(chain, parent), to, chain)
    {added, removed ++ [from]}
  end

  def diff(%Block{index: i} = from, %Block{index: j, parent: parent} = to, chain) when i < j do
    {added, removed} = diff(from, Chain.lookup(chain, parent), chain)
    {added ++ [to], removed}
  end

  def diff(%Block{parent: pf} = from, %Block{parent: pt} = to, chain) do
    {added, removed} = diff(Chain.lookup(chain, pf), Chain.lookup(chain, pt), chain)
    {added ++ [to], removed ++ [from]}
  end

  @doc """
  Fetch the missing blocks from other peers
  """
  def fetch_missing(nil, _peers, _chain), do: :ok
  def fetch_missing(<<>>, _peers, _chain), do: :ok

  def fetch_missing(hash, peers, chain) do
    if Chain.lookup(chain, hash) == nil do
      Logger.info("Asking peers for #{Base.url_encode64(hash, padding: false)}")

      block =
        for peer <- peers do
          GenServer.call(peer, {:fetch, hash})
        end
        |> Enum.find(fn
          %Block{} -> true
          _ -> false
        end)

      unless block == nil do
        Chain.insert(chain, block)
        fetch_missing(block.parent, peers, chain)

        for peer <- peers do
          GenServer.cast(peer, {:insert_block, block})
        end

        :ok
      else
        :err
      end
    else
      :ok
    end
  end

  def handle_info(
        :mine,
        %{pending: transactions, head: head, reward_to: reward_to, chain: chain} = state
      ) do
    reward = if reward_to, do: [Transaction.reward(reward_to)], else: []

    block = %Block{
      index: next_index(chain, head),
      transactions: MapSet.to_list(transactions) ++ reward,
      parent: head
    }

    worker = self()

    Logger.info(
      "Start to mine block ##{block.index} (#{length(block.transactions)} transactions)"
    )

    {:ok, pid} =
      Task.start(fn ->
        mined = Block.optimize(block) |> Block.mine()
        GenServer.cast(worker, {:insert_block, mined})
      end)

    {:noreply, %{state | timer: nil, task: pid}}
  end

  def handle_call({:balance, account}, _from, %{accounts: accounts} = state) do
    {:reply, Map.get(accounts, account, 0), state}
  end

  def handle_call(:head, _from, %{head: head} = state), do: {:reply, head, state}

  def handle_call(:chain, _from, %{chain: chain} = state), do: {:reply, chain, state}

  def handle_call({:fetch, hash}, _from, %{chain: chain} = state),
    do: {:reply, Chain.lookup(chain, hash), state}

  def handle_cast(
        {:queue, tx},
        %{pending: pending, accounts: accounts, tx_hashes: tx_hashes} = state
      ) do
    pending = MapSet.put(pending, tx)

    # Try to apply pending transactions
    # TODO: log errors
    case Transaction.run(accounts, tx_hashes, MapSet.to_list(pending)) do
      {:error, _} ->
        {:noreply, state}

      {:ok, _, _} ->
        {:noreply, %{state | pending: pending}}
    end
  end

  def handle_cast({:add_peer, peer}, %{peers: peers} = state) do
    unless MapSet.member?(peers, peer) do
      GenServer.cast(peer, {:add_peer, self()})
      {:noreply, %{state | peers: MapSet.put(peers, peer)}}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:start, state) do
    timer = Process.send_after(self(), :mine, 100)
    {:noreply, %{state | timer: timer}}
  end

  def handle_cast({:claim, pubkey}, state), do: {:noreply, %{state | reward_to: pubkey}}

  def handle_cast(
        {:insert_block, block},
        %{
          chain: chain,
          head: head,
          pending: pending,
          accounts: accounts,
          tx_hashes: tx_hashes,
          peers: peers,
          timer: timer,
          task: task
        } = state
      ) do
    hash = Block.hash(block)

    unless Chain.lookup(chain, hash) != nil do
      Logger.info("Broadcasting new block #{inspect({self(), block.index})}\n#{block}")

      for peer <- peers do
        GenServer.cast(peer, {:insert_block, block})
      end

      :ok = fetch_missing(block.parent, peers, chain)
      Chain.insert(chain, block)
    end

    state =
      if next_index(chain, head) <= block.index do
        Logger.info("Accepting new head")
        {added, removed} = diff(Chain.lookup(chain, head), block, chain)

        map = fn
          {:error, _} -> {:halt, :err}
          {:ok, accounts, tx_hashes} -> {:cont, {accounts, tx_hashes}}
        end

        acc =
          Enum.reduce_while(removed, {accounts, tx_hashes}, fn block, {accounts, tx_hashes} ->
            Transaction.rollback(accounts, tx_hashes, block.transactions) |> map.()
          end)

        case acc do
          :err ->
            state

          acc ->
            acc =
              Enum.reduce_while(added, acc, fn block, {accounts, tx_hashes} ->
                Transaction.run(accounts, tx_hashes, block.transactions) |> map.()
              end)

            case acc do
              :err ->
                state

              {accounts, tx_hashes} ->
                added_txs =
                  Enum.reduce(added, [], fn %Block{transactions: txs}, acc -> acc ++ txs end)

                pending =
                  Enum.reduce(removed, MapSet.to_list(pending), fn %Block{transactions: txs}, p ->
                    p ++ Enum.reject(txs, &Transaction.is_reward?/1)
                  end)
                  |> Enum.reject(fn t_pending ->
                    Enum.any?(added_txs, fn t_block ->
                      Transaction.hash(t_block) == Transaction.hash(t_pending)
                    end)
                  end)

                %{
                  state
                  | accounts: accounts,
                    tx_hashes: tx_hashes,
                    head: hash,
                    pending: MapSet.new(pending)
                }
            end
        end
      else
        state
      end

    if task != nil and Process.alive?(task) do
      Process.exit(task, :kill)
    end

    timer =
      if timer == nil or Process.read_timer(timer) == false do
        Process.send_after(self(), :mine, 1000 * 5)
      else
        timer
      end

    {:noreply, %{state | timer: timer, task: nil}}
  end
end
