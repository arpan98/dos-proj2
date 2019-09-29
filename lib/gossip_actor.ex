defmodule Gossip.Actor do
  use GenServer

  @rumorlimit 10
  @ticktime 100

  # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def send_gossip(neighbors) do
    neighbors |> Enum.random() |> GenServer.cast({:gossip, "rumor not set"})
  end

  # Server
  def init([statsPID | _]) do
    {:ok, %{rumorCount: 0, statsPID: statsPID}}
  end

  def handle_cast({:gossip, rumor}, state) do
    # IO.puts("Got rumor. Rumor count = #{state.rumorCount}")
    rumorCount = state.rumorCount + 1
    new_state = %{state | rumorCount: rumorCount}
    if rumorCount == @rumorlimit do
      IO.puts("#{inspect(self())} rumor count #{rumorCount}")
      GenServer.cast(state.statsPID, :terminate)
    end
    {:noreply, new_state}
  end

  def handle_cast({:neighbors, neighbors}, state) do
    new_state = Map.put(state, :neighbors, neighbors)
    tick()
    {:noreply, new_state}
  end

  def handle_info(:tock, state) do
    tick()
    send_gossip(state.neighbors)
    {:noreply, state}
  end

  def tick() do
    Process.send_after(self(), :tock, @ticktime)
  end

end
