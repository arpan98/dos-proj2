defmodule Gossip.Actor do
  use GenServer

  @rumorlimit 20
  @ticktime 10

  # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def send_gossip(neighbors, rumor, _statsPID) do
    if Enum.empty?(neighbors) do
      # GenServer.call(statsPID, {:terminate_all, :gossip, :no_neighbors})
    else
      next = neighbors |> Enum.random()
      next |> GenServer.cast({:gossip, rumor})
    end
  end

  # Server
  def init([statsPID, _, failure_prob]) do
    {:ok, %{
      rumor: "",
      rumorCount: 0,
      statsPID: statsPID,
      failure_prob: failure_prob
      }
    }
  end

  def handle_call(:remove_neighbor, from, state) do
    {pid, _} = from
    new_neighbors = Enum.reject(state.neighbors, fn neighbor -> neighbor == pid end)
    new_state = %{state | neighbors: new_neighbors}
    {:reply, new_state, new_state}
  end

  def handle_cast({:gossip, rumor}, state) do
    # IO.puts("Got rumor. Rumor count = #{state.rumorCount}")
    rumorCount = state.rumorCount + 1
    new_state = %{state | rumor: rumor, rumorCount: rumorCount}
    if rumorCount == 1 do
      send_gossip(state.neighbors, rumor, state.statsPID)
      tick()
    end
    if rumorCount == @rumorlimit do
      GenServer.call(state.statsPID, :terminateGossip)
      Enum.each(state.neighbors, fn neighbor -> GenServer.call(neighbor, :remove_neighbor, :infinity) end)
    end
    {:noreply, new_state}
  end

  def handle_cast({:neighbors, neighbors}, state) do
    new_state = Map.put(state, :neighbors, neighbors)
    {:noreply, new_state}
  end

  def handle_info(:tock, state) do
    tick()
    if state.rumorCount > 0 and state.rumorCount <= @rumorlimit do
      if can_send(state.failure_prob) do
        send_gossip(state.neighbors, state.rumor, state.statsPID)
      end
    end
    {:noreply, state}
  end

  defp tick() do
    Process.send_after(self(), :tock, @ticktime)
  end

  defp can_send(p) do
    roll = :rand.uniform()
    if roll >= p, do: true, else: false
  end

end
