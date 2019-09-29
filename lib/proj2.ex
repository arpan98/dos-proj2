defmodule Proj2 do

  def main(argv) do
    argv
    |> parse_input
    |> run
  end

  defp parse_input([num_of_nodes, topology, algorithm]) do
    [String.to_integer(num_of_nodes), String.downcase(topology), String.downcase(algorithm)]
  end

  defp run([num_of_nodes, topology, algorithm]) when algorithm == "gossip" do
    num_of_nodes = round_up(num_of_nodes, topology)
    {:ok, statsPID} = GenServer.start_link(Stats, [num_of_nodes])
    Topology.create_topology(num_of_nodes, topology, statsPID, Gossip.Actor)
    {_, pid, _, _} = Supervisor.which_children(NodeSupervisor) |> Enum.random
    GenServer.call(statsPID, :startTimer)
    GenServer.cast(pid, {:gossip, "psst"})
    loop()
  end

  defp run([num_of_nodes, topology, algorithm]) when algorithm == "push-sum" do
    num_of_nodes = round_up(num_of_nodes, topology)
    {:ok, statsPID} = GenServer.start_link(Stats, [num_of_nodes])
    Topology.create_topology(num_of_nodes, topology, statsPID, PushSum.Actor)
    {_, pid, _, _} = Supervisor.which_children(NodeSupervisor) |> Enum.random
    GenServer.call(statsPID, :startTimer)
    GenServer.cast(pid, {:push_sum, 0, 0})
    loop()
  end

  defp round_up(numNodes, topology) do
    case topology do
      t when t in ["full", "line", "rand2D"] -> numNodes

      "3Dtorus" ->
        numNodes |> :math.sqrt() |> ceil() |> :math.pow(3) |> trunc()

      t when t in ["honeycomb", "randhoneycomb"] ->
        numNodes |> :math.sqrt() |> ceil() |> :math.pow(2) |> trunc()
    end
  end

  def loop() do
    receive do
      :end -> exit(:shutdown)
    end
  end
end
