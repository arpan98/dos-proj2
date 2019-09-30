defmodule PushSum.Actor do
  use GenServer, restart: :transient

  def start_link(argv) do
    GenServer.start_link(__MODULE__, argv)
  end

  def init([statsPID, i, _]) do
    {:ok, %{id: i, neighbors: [], sum: i, weight: 1, ratio: i/1, round: 0, statsPID: statsPID}}
  end

  def handle_call({:get_state}, _from, state) do
    IO.inspect state
    {:reply, state, state}
  end

  def handle_cast({:neighbors, neighbors}, state) do
    new_state = %{state | neighbors: neighbors}
    {:noreply, new_state}
  end

  def handle_cast({:push_sum, s, w}, state) do
    {sum, weight, round} = {state[:sum] + s, state[:weight] + w, state[:round] + 1}
    ratio = sum / weight
    # IO.puts ~s"#{inspect(self())} with #{inspect({state[:sum], state[:weight], state[:ratio], state[:round]})} received #{inspect({s, w})}"
    new_state = %{state | sum: sum/2, weight: weight/2, ratio: ratio}
    neighbors = new_state[:neighbors] |> Enum.filter(fn x -> Process.alive?(x) end)
    new_state = cond do
      neighbors == [] ->
        IO.puts ~s"Terminating #{inspect(self())} - empty neighbour list"
        send_msg(state.statsPID, nil, sum, weight)
        new_state
      abs(state[:ratio] - ratio) > :math.pow(10, -10) ->
        {neighbors, next_pid} = neighbors |> get_neighbor()
        send_msg(state.statsPID, next_pid, sum, weight)
        %{new_state | round: 0, neighbors: neighbors}
      abs(state[:ratio] - ratio) <= :math.pow(10, -10) and round < 3 ->
        {neighbors, next_pid} = neighbors |> get_neighbor()
        send_msg(state.statsPID, next_pid, sum, weight)
        %{new_state | round: round, neighbors: neighbors}
      abs(state[:ratio] - ratio) <= :math.pow(10, -10) and round >= 3 ->
        {neighbors, next_pid} = neighbors |> get_neighbor()
        send_msg(state.statsPID, next_pid, sum, weight)
        IO.puts ~s"\Terminating #{inspect(self())} - sum estimate converge"
        GenServer.cast(state.statsPID, {:terminate_process, self()} )
        %{new_state | round: round, neighbors: neighbors}
    end
    {:noreply, new_state}
  end

  defp send_msg(stats_pid, pid, sum, weight) do
    if pid != nil do
      pid |> GenServer.cast({:push_sum, sum/2, weight/2})
    else
      GenServer.cast(stats_pid, :terminate_all)
    end
  end

  defp get_neighbor(neighbors) do
    cond do
      neighbors == [] -> {[], nil}
      true ->
        next_pid = neighbors |> Enum.random()
        # IO.inspect next_pid
        case Process.alive?(next_pid) do
          false -> neighbors |> Enum.filter(fn pid -> next_pid != pid end) |> get_neighbor()
          true -> {neighbors, next_pid}
      end
    end
  end

end
