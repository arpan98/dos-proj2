defmodule Gossip.Actor do
  use GenServer

  # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  # Server
  def init(arg) do
    [neighbors] = arg
    tick()
    {:ok, %{neighbors: neighbors, rumorCount: 0}}
  end

  def handle_cast({:gossip, rumor}, state) do
    IO.puts("Got rumor #{rumor}")
    rumorCount = state.rumorCount + 1
    new_state = %{state | rumorCount: rumorCount}
    if rumorCount == 10 do
      IO.puts("#{self()} rumor count 10")
    end
    {:noreply, new_state}
  end

  def handle_info(:tock, state) do
    tick()
    {:noreply, state}
  end

  def tick() do
    Process.send_after(self(), :tock, 1000)
  end

end