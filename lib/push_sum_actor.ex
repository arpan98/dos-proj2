defmodule PushSum.Actor do
  use GenServer, restart: :transient

  def start_link(argv) do
    GenServer.start_link(__MODULE__, argv)
  end

  def init([statsPID, i, failure_prob]) do
    {:ok, %{
        neighbors: [],
        sum: i,
        weight: 1,
        ratio: i/1,
        round: 0,
        statsPID: statsPID,
        running: true,
        failure_prob: failure_prob
      }
    }
  end

  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:neighbors, neighbors}, state) do
    new_state = %{state | neighbors: neighbors}
    {:noreply, new_state}
  end

  def handle_cast({:push_sum, s, w}, state) do
    {sum, weight, round} = {(state[:sum] + s) / 2, (state[:weight] + w) / 2, state[:round] + 1}
    ratio = sum / weight
    new_state = %{state | sum: sum, weight: weight, ratio: ratio}
    neighbors = new_state[:neighbors]
    new_state = cond do
      neighbors == [] ->
        send_msg(state.statsPID, nil, sum, weight, state.failure_prob)
        new_state

      abs(state[:ratio] - ratio) > :math.pow(10, -10) ->
        {neighbors, next_pid} = neighbors |> get_neighbor()
        send_msg(state.statsPID, next_pid, sum, weight, state.failure_prob)
        %{new_state | round: 0, neighbors: neighbors} # reset rounds of counting change

      abs(state[:ratio] - ratio) <= :math.pow(10, -10) and round < 3 ->
        {neighbors, next_pid} = neighbors |> get_neighbor()
        send_msg(state.statsPID, next_pid, sum, weight, state.failure_prob)
        %{new_state | round: round, neighbors: neighbors}

      abs(state[:ratio] - ratio) <= :math.pow(10, -10) and round >= 3 ->
        # GenServer.call(state.statsPID, {:terminate_process, self()})
        {neighbors, next_pid} = neighbors |> get_neighbor()
        send_msg(state.statsPID, next_pid, sum, weight, state.failure_prob)
        %{new_state | round: round, neighbors: neighbors, running: false} # set running = False
    end
    {:noreply, new_state}
  end

  defp send_msg(stats_pid, next_pid, sum, weight, failure_prob) do
    if next_pid != nil do
      if can_send(failure_prob) do
        # IO.puts ~s"Process #{inspect(self())} sending #{inspect({sum / weight})} to  #{inspect(next_pid)}"
        next_pid |> GenServer.cast({:push_sum, sum, weight})
      else
        GenServer.call(stats_pid, {:terminate_all, :push_sum, :failure})
      end
    else
      GenServer.call(stats_pid, {:terminate_all, :push_sum, :no_neighbors})
    end
  end

  defp get_neighbor(neighbors) do
    cond do
      neighbors == [] -> {[], nil}
      true ->
        next_pid = neighbors |> Enum.random()
        case GenServer.call(next_pid, {:get_state}).running do
          false -> neighbors |> Enum.filter(fn pid -> next_pid != pid end) |> get_neighbor()
          true -> {neighbors, next_pid}
        end
    end
  end

  defp can_send(p) do
    roll = :rand.uniform()
    if roll >= p, do: true, else: false
  end

end
