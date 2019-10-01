defmodule Stats do
  use GenServer

    # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def printTimeDiff(state) do
    diff = System.convert_time_unit(state.endTime - state.startTime, :native, :millisecond)
    IO.puts("Convergence time = #{diff} ms. Time step = 100 ms")
  end

  # Server
  def init(arg) do
    [num_of_nodes, topology, main_pid] = arg
    terminating_percent = case topology do
      "full" -> 80
      "line" -> 70
      "rand2d" -> 80
      "3dtorus" -> 80
      "honeycomb" -> 70
      "randhoneycomb" -> 70
      _ -> 70
    end
    {:ok, %{main_pid: main_pid, startTime: 0, endTime: 0, total_nodes: num_of_nodes, nodes_running: num_of_nodes, term_per: terminating_percent}}
  end

  def handle_cast({:store_nodes, nodes}, state) do
    IO.inspect nodes
    new_state = Map.put(state, :nodes, nodes)
    {:noreply, new_state}
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

  def handle_cast(:terminateGossip, state) do
    nodes_left = state.nodes_running - 1
    percentage = (state.total_nodes - nodes_left) * 100 / state.total_nodes
    IO.inspect(percentage)
    if percentage >= state.term_per do
      cur_time = System.monotonic_time()
      new_state = %{state | endTime: cur_time, nodes_running: nodes_left}
      printTimeDiff(new_state)
      send(state.main_pid, :end)
      {:noreply, new_state}      
    else
      new_state = %{state | nodes_running: nodes_left}
      {:noreply, new_state}
    end
  end

  def handle_cast({:terminate_process, pid}, state) do
    compute_time(state.main_pid, pid, state.startTime)
    new_state = %{state | nodes: state.nodes |> Enum.reject(fn x -> x == pid end)}
    {:noreply, new_state}
  end

  def handle_cast(:terminate_all, state) do
    IO.puts ~s"Terminating all other processes waiting for a message ... ..."
    IO.inspect state.nodes
    nodes = state.nodes |> Enum.map(fn pid ->
      compute_time(state.main_pid, pid, state.startTime)
    end)
    new_state = %{state | nodes: nodes}
    IO.puts ~s"Terminating main process ... ..."
    send(state.main_pid, :end)
    {:noreply, new_state}
  end

  defp compute_time(main_pid, pid, start_time) do
    if Process.alive?(pid) do
      Process.exit(pid, :kill)
      cur_time = System.monotonic_time()
      diff = System.convert_time_unit(cur_time - start_time, :native, :millisecond)
      IO.puts ~s"Time taken to converge #{inspect(pid)} is #{inspect(diff)}."
      main_pid |> send({:node_time, [pid, diff]})
    end
  end

end
