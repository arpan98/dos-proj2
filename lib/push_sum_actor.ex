defmodule PushSum.Actor do
  use GenServer, restart: :transient

  def start_link(argv) do
    GenServer.start_link(__MODULE__, argv)
  end

  def init([statsPID, i]) do
    {:ok, %{id: i, neighbors: [], sum: i, weight: 1, ratio: i/1, round: 0, statsPID: statsPID}}
  end

  def handle_call({:get_state}, _from, state) do
    IO.inspect state
    {:reply, state, state}
  end

  def handle_cast({:neighbors, neighbors}, state) do
    new_state = Map.put(state, :neighbors, neighbors)
    {:noreply, new_state}
  end

  def handle_cast({:push_sum, s, w}, state) do
    {sum, weight, round} = {state[:sum] + s/2, state[:weight] + w/2, state[:round] + 1}
    ratio = sum/weight
    IO.puts ~s"\n#{inspect(self())} with #{inspect({state[:sum], state[:weight], state[:ratio], state[:round]})} received #{inspect({s, w})}"
    new_state = Map.put(state, :sum, sum) |> Map.put(:weight, weight) |> Map.put(:ratio, ratio)
    neighbors = new_state[:neighbors] |> Enum.filter(fn x -> Process.alive?(x) end)
    new_state = cond do
      # neighbors == [] ->
      #   IO.puts ~s"Terminating #{inspect(self())} due to empty neighbour list"
      #   GenServer.cast(state.statsPID, :terminate)
      #   Process.exit(self(), :kill)
      #   new_state
      abs(state[:ratio] - ratio) > :math.pow(10, -10) ->
        neighbors |> Enum.random() |> GenServer.cast({:push_sum, sum/2, weight/2})
        Map.put(new_state, :round, 0)
      abs(state[:ratio] - ratio) <= :math.pow(10, -10) and round < 3 ->
        neighbors |> Enum.random() |> GenServer.cast({:push_sum, sum/2, weight/2})
        Map.put(new_state, :round, round)
      abs(state[:ratio] - ratio) <= :math.pow(10, -10) and round >= 3 ->
        # neighbors |> Enum.random() |> GenServer.cast({:push_sum, sum/2, weight/2})
        IO.puts ~s"Terminating #{inspect(self())} since values never converge"
        GenServer.cast(state.statsPID, :terminate)
        # Process.exit(self(), :kill)
        Map.put(new_state, :round, round)
    end
    {:noreply, new_state}
  end

end
