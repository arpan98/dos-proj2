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
    {:ok, statsPID} = GenServer.start_link(Stats, [num_of_nodes, self()])
    Topology.create_topology(num_of_nodes, topology, statsPID, Gossip.Actor, failure_prob)
    {_, pid, _, _} = Supervisor.which_children(NodeSupervisor) |> Enum.random
    GenServer.call(statsPID, :startTimer)
    GenServer.cast(pid, {:gossip, "psst"})
    loop()
  end

  defp run([num_of_nodes, topology, algorithm, failure_prob]) when algorithm == "push-sum" do
    num_of_nodes = round_up(num_of_nodes, topology)
    {:ok, statsPID} = GenServer.start_link(Stats, [num_of_nodes, self()])
    Topology.create_topology(num_of_nodes, topology, statsPID, PushSum.Actor, failure_prob)
    {_, pid, _, _} = Supervisor.which_children(NodeSupervisor) |> Enum.random
    GenServer.call(statsPID, :startTimer)
    GenServer.cast(pid, {:push_sum, 0, 0})
    loop()
  end

  defp round_up(num_of_nodes, topology) do
    case topology do
      t when t in ["full", "line", "rand2d"] -> num_of_nodes

      "3dtorus" -> num_of_nodes |> :math.pow(1/3) |> trunc() |> :math.pow(3) |> trunc()

      t when t in ["honeycomb", "randhoneycomb"] ->
        num_of_nodes |> :math.sqrt() |> ceil() |> :math.pow(2) |> trunc()
    end
  end

  def loop() do
    receive do
      :end -> exit(:shutdown)
    end
  end
end
