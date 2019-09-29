defmodule Gossip.Actor do
  use GenServer

  @rumorlimit 10
  @ticktime 10

  # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def send_gossip(neighbors) do
    neighbors |> Enum.random() |> GenServer.cast({:gossip, "some rumor"})
  end

  # Server
  def init([statsPID, _, failure_prob]) do
    {:ok, %{rumorCount: 0, statsPID: statsPID, failure_prob: failure_prob}}
  end

  def handle_cast({:gossip, _rumor}, state) do
    # IO.puts("Got rumor. Rumor count = #{state.rumorCount}")
    rumorCount = state.rumorCount + 1
    new_state = %{state | rumorCount: rumorCount}
    if rumorCount == 1 do
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
    if state.rumorCount > 0 and state.rumorCount <= @rumorlimit do
      if can_send(state.failure_prob) do
        send_gossip(state.neighbors)
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
