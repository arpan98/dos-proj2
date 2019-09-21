defmodule Stats do
  use GenServer

    # Client
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def printTimeDiff(state) do
    diff = System.convert_time_unit(state.endTime - state.startTime, :native, :millisecond)
    IO.puts("#{diff}") 
  end

  # Server
  def init(arg) do
    [numNodes] = arg
    {:ok, %{startTime: 0, endTime: 0, nodes_running: numNodes}}
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
    nodes_left = state.nodes_running - 1
    if nodes_left == 0 do
      new_state = %{state | endTime: System.monotonic_time(), nodes_running: nodes_left}
      printTimeDiff(new_state)
      {:noreply, new_state}
    else
      new_state = %{state | nodes_running: nodes_left}
      {:noreply, new_state}
    end
  end
    
end