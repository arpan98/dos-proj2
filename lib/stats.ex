defmodule Stats do
  use GenServer

    # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  # Server
  def init(arg) do
    [num_of_nodes, topology, main_pid] = arg
    terminating_percent = case topology do
      "full" -> 80
      "line" -> 60
      "rand2d" -> 70
      "3dtorus" -> 80
      "honeycomb" -> 70
      "randhoneycomb" -> 70
      _ -> 70
    end
    {:ok, %{
      main_pid: main_pid,
      startTime: 0,
      endTime: 0,
      total_nodes: num_of_nodes,
      nodes_terminated: 0,
      term_per: terminating_percent
      }
    }
  end

  def handle_call(:startTimer, _from, state) do
    new_state = %{state | startTime: System.monotonic_time()}
    {:reply, new_state, new_state}
  end

  def handle_call(:endTimer, _from, state) do
    new_state = %{state | endTime: System.monotonic_time()}
    {:reply, new_state, new_state}
  end

  def handle_call(:getTimeDiff, _from, state) do
    {:reply, state.endTime - state.startTime, state}
  end

  def handle_call(:terminateGossip, _from, state) do
    # {pid, _} = from
    nodes_terminated = state.nodes_terminated + 1
    percentage = nodes_terminated * 100 / state.total_nodes
    # IO.puts("#{inspect(pid)} done. #{percentage}")
    if percentage >= state.term_per do
      cur_time = System.monotonic_time()
      new_state = %{state | endTime: cur_time, nodes_terminated: nodes_terminated}
      send(state.main_pid, {:end, [state.startTime, cur_time], {:normal, percentage}})
      {:reply, new_state, new_state}      
    else
      new_state = %{state | nodes_terminated: nodes_terminated}
      {:reply, new_state, new_state}
    end
  end

  def handle_call({:terminate_all, algorithm, reason}, _from, state) do
    # IO.puts ~s"Terminating all other alive processes ... ..."
    cur_time = System.monotonic_time()
    case algorithm do
      :gossip -> 
        percentage = state.nodes_terminated * 100 / state.total_nodes
        state.main_pid |> send({:end, [state.startTime, cur_time], {:no_neighbors, percentage}})

      :push_sum -> state.main_pid |> send({:end, [state.startTime, cur_time], reason})
    end
    {:reply, true, state}
  end

end
