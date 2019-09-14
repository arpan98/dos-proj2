defmodule Topology do

  def create_topology(numNodes, topology) do
    IO.puts("Topology #{topology} with #{numNodes} nodes")

    nodes = 1..10

    children = nodes
    |> Enum.map(fn i ->
      Supervisor.child_spec({Gossip.Actor, [get_neighbors(nodes, i, topology)]}, id: {Gossip.Actor, i})
    end)
    Supervisor.start_link(children, strategy: :one_for_one, name: GossipSupervisor)
  end

  defp get_neighbors(nodes, nodeIndex, topology) do
    case topology do
      "full" -> nodes
        |> Enum.reject(fn x -> x == nodeIndex end)
      _ -> IO.puts("Currently only supporting full topology")
    end
  end

end