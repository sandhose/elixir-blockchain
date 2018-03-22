defmodule Blockchain.Worker do
  use GenServer
  require Logger

  alias Blockchain.{Block, Chain, Transaction}

  @type t() :: %{
          pending: [%Transaction{}],
          head: Block.h(),
          timer: reference() | nil,
          task: pid() | nil
        }

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    Chain.init()
    timer = Process.send_after(self(), :mine, 10 * 1000)
    {:ok, %{pending: [], head: <<>>, timer: timer, task: nil}}
  end

  def handle_info(:mine, %{pending: transactions, head: head} = state) do
    block = %Block{transactions: transactions, parent: head}
    worker = self()

    Logger.info("Start to mine #{block}")

    {:ok, pid} =
      Task.start(fn ->
        mined = Block.mine(block)
        GenServer.cast(worker, {:mined, mined})
      end)

    {:noreply, %{state | timer: nil, task: pid}}
  end

  def handle_cast(
        {:mined, block},
        %{pending: pending, head: head, timer: timer, task: task} = state
      ) do
    state =
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

        %{state | pending: pending, head: head, timer: timer, task: nil}
      else
        state
      end

    {:noreply, state}
  end
end
