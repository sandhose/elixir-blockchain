defmodule Blockchain.Worker do
  use GenServer
  require Logger

  alias Blockchain.{Block, Chain, Transaction}

  @type accounts() :: %{Ed25519.key() => float}
  @type tx_hashes() :: MapSet.t(binary())

  @type t() :: %{
          pending: [%Transaction{}],
          head: Block.h(),
          timer: reference() | nil,
          accounts: accounts(),
          tx_hashes: tx_hashes(),
          reward_to: Ed25519.key() | nil,
          task: pid() | nil
        }

  def start_link(_) do
    # TODO: worker name is temporary
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def claim(pub), do: GenServer.cast(__MODULE__, {:claim, pub})
  def start, do: GenServer.cast(__MODULE__, :start)
  def head, do: GenServer.call(__MODULE__, :head)

  @spec init(:ok) :: {:ok, t()}
  def init(:ok) do
    Chain.init()

    {:ok,
     %{
       pending: [],
       head: <<>>,
       timer: nil,
       accounts: %{},
       tx_hashes: MapSet.new(),
       reward_to: nil,
       task: nil
     }}
  end

  def handle_info(:mine, %{pending: transactions, head: head, reward_to: reward_to} = state) do
    reward = if reward_to, do: [Transaction.reward(reward_to)], else: []
    block = %Block{transactions: transactions ++ reward, parent: head}
    worker = self()

    Logger.info("Start to mine #{block}")

    {:ok, pid} =
      Task.start(fn ->
        mined = Block.mine(block)
        GenServer.cast(worker, {:mined, mined})
      end)

    {:noreply, %{state | timer: nil, task: pid}}
  end

  def handle_call(:head, _from, %{head: head} = state), do: {:reply, head, state}

  def handle_cast(:start, state) do
    timer = Process.send_after(self(), :mine, 0)
    {:noreply, %{state | timer: timer}}
  end

  def handle_cast({:claim, pubkey}, state), do: {:noreply, %{state | reward_to: pubkey}}

  def handle_cast(
        {:mined, block},
        %{
          pending: pending,
          head: head,
          timer: timer,
          accounts: accounts,
          tx_hashes: tx_hashes,
          task: task
        } = state
      ) do
    # TODO: timers are not always restarted
    state =
      case Transaction.run(accounts, tx_hashes, block.transactions) do
        {:error, tx} ->
          Logger.error("Transaction #{tx} is illegal, voiding block")
          state

        {:ok, accounts, tx_hashes} ->
          if Chain.valid?(block) do
            Logger.info("New block mined: #{block}")

            if task != nil and Process.alive?(task) do
              Process.exit(task, :kill)
            end

            if timer != nil and Process.read_timer(timer) != false do
              Process.cancel_timer(timer)
            end

            Chain.insert(block)

            timer = Process.send_after(self(), :mine, 10 * 1000)

            head = Block.hash(block)

            pending =
              Enum.filter(pending, fn t_pending ->
                Enum.any?(block.transactions, fn t_block ->
                  Transaction.hash(t_block) == Transaction.hash(t_pending)
                end)
              end)

            %{
              state
              | pending: pending,
                accounts: accounts,
                tx_hashes: tx_hashes,
                head: head,
                timer: timer,
                task: nil
            }
          else
            Logger.error("Block invalid in chain")
            state
          end
      end

    {:noreply, state}
  end
end
