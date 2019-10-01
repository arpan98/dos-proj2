defmodule Proj2 do

  def main(argv) do
    argv
    |> parse_input
    |> run
  end

  defp parse_input([num_of_nodes, topology, algorithm]) do
    [String.to_integer(num_of_nodes), String.downcase(topology), String.downcase(algorithm), 0]
  end

  defp parse_input([num_of_nodes, topology, algorithm, failure_prob]) do
    {p, _} = Float.parse(failure_prob)
    [String.to_integer(num_of_nodes), String.downcase(topology), String.downcase(algorithm), p]
  end

  defp run([num_of_nodes, topology, algorithm, failure_prob]) when algorithm == "gossip" do
    num_of_nodes = round_up(num_of_nodes, topology)
    IO.puts ~s"\nNode Count: #{inspect(num_of_nodes)}, Topology: #{inspect(topology)}, Algorithm: #{inspect(algorithm)}, Failure Prob: #{inspect(failure_prob)}, Time step = 10 ms"
    {:ok, statsPID} = GenServer.start_link(Stats, [num_of_nodes, topology, self()])
    Topology.create_topology(num_of_nodes, topology, statsPID, Gossip.Actor, failure_prob)
    {_, pid, _, _} = Supervisor.which_children(NodeSupervisor) |> Enum.random
    IO.puts("Starting Gossip algorithm. Gossip limit: 20 messages")
    GenServer.call(statsPID, :startTimer)
    GenServer.cast(pid, {:gossip, "psst"})
    loop()
  end

  defp run([num_of_nodes, topology, algorithm, failure_prob]) when algorithm == "push-sum" do
    num_of_nodes = round_up(num_of_nodes, topology)
    IO.puts ~s"\nNode Count: #{inspect(num_of_nodes)}, Topology: #{inspect(topology)}, Algorithm: #{inspect(algorithm)}, Failure Prob: #{inspect(failure_prob)}"
    {:ok, statsPID} = GenServer.start_link(Stats, [num_of_nodes, topology, self()])
    Topology.create_topology(num_of_nodes, topology, statsPID, PushSum.Actor, failure_prob)
    nodes = Supervisor.which_children(NodeSupervisor) |> Enum.map(fn {_, pid, _, _} -> pid end)
    IO.puts("Starting Push-Sum algorithm")
    GenServer.call(statsPID, :startTimer)
    Enum.random(nodes) |> GenServer.cast({:push_sum, 0, 0})
    loop()
  end

  defp round_up(num_of_nodes, topology) do
    case topology do
      t when t in ["full", "line", "rand2d"] -> num_of_nodes

      "3dtorus" -> num_of_nodes |> :math.pow(1/3) |> ceil() |> :math.pow(3) |> trunc()

      t when t in ["honeycomb", "randhoneycomb"] ->
        num_of_nodes |> :math.sqrt() |> ceil() |> :math.pow(2) |> trunc()
    end
  end

  def loop() do
    receive do
      {:end, [start_time, end_time], reason} ->
        case reason do
          :failure -> IO.puts("Terminating criteria: Message failure")
          :no_neighbors -> IO.puts("Terminating criteria: No more active neighbors")
          {:no_neighbors, p} -> IO.puts("Terminating criteria: No more active neighbors\n#{Float.ceil(p, 3)} % convergence attained")
          {:normal, p} -> IO.puts("Terminating criteria: #{Float.ceil(p, 3)} % convergence attained")
        end
        diff = System.convert_time_unit(end_time - start_time, :native, :millisecond)
        IO.puts ~s"Running Time: #{diff} milliseconds."
        exit(:shutdown)
    end
  end

end
