defmodule Stats do
  use GenServer

    # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def printTimeDiff(state) do
    diff = System.convert_time_unit(state.endTime - state.startTime, :native, :millisecond)
    IO.puts("#{diff} ms. Time step = 100 ms")
  end

  # Server
  def init(arg) do
    [num_of_nodes, main_pid] = arg
    {:ok, %{main_pid: main_pid, startTime: 0, endTime: 0, total_nodes: num_of_nodes, nodes_running: num_of_nodes}}
  end

  def handle_cast({:store_nodes, nodes}, state) do
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

  def handle_cast(:terminate, state) do
    cur_time = System.monotonic_time()
    diff = System.convert_time_unit(cur_time - state.startTime, :native, :millisecond)
    nodes_left = state.nodes_running - 1
    percentage = (state.total_nodes - nodes_left) * 100 / state.total_nodes
    IO.puts("#{percentage} #{diff}")
    # IO.puts("Nodes terminated = #{state.total_nodes - nodes_left} / #{state.total_nodes}")
    if nodes_left == 0 do
      new_state = %{state | endTime: System.monotonic_time(), nodes_running: nodes_left}
      printTimeDiff(new_state)
      send(state.main_pid, :end)
      {:noreply, new_state}
    else
      new_state = %{state | nodes_running: nodes_left}
      {:noreply, new_state}
    end
  end

  def handle_call({:terminate_process, pid}, _from, state) do
    # IO.puts ~s"Terminating processes #{inspect(pid)} ..."
    new_state = %{state | nodes: state.nodes |> Enum.reject(fn x -> x == pid end)}
    {:reply, true, new_state}
  end

  def handle_call(:terminate_all, _from, state) do
    # IO.puts ~s"Terminating all other alive processes ... ..."
    state.main_pid |> send({:end, [state.startTime, System.monotonic_time()]})
    {:reply, true, state}
  end

end
