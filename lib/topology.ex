defmodule Topology do

  def create_topology(numNodes, topology, statsPID) do
    IO.puts("Topology #{topology} with #{numNodes} nodes")

    nodes = 1..numNodes

    children = nodes
    |> Enum.map(fn i ->
      Supervisor.child_spec({Gossip.Actor, [statsPID]}, id: {Gossip.Actor, i})
    end)
    Supervisor.start_link(children, strategy: :one_for_one, name: GossipSupervisor)

    nodes = Enum.map(Supervisor.which_children(GossipSupervisor), fn child ->
      {_, pid, _, _} = child
      pid
    end)
    Enum.each(nodes, fn node ->
      assign_neighbors(node, nodes) |> send_neighbors()
    end)
  end

  defp send_neighbors({cur_node, neighbors}) do
    GenServer.cast(cur_node, {:neighbors, neighbors})
  end

  def assign_neighbors(cur_node, nodes) do
    {cur_node, Enum.reject(nodes, fn x -> x == cur_node end)}
  end

  defp get_neighbors(nodes, nodeIndex, topology) do
    case topology do
      "full" -> nodes
        |> Enum.reject(fn x -> x == nodeIndex end)
      _ -> IO.puts("Currently only supporting full topology")
    end
  end

end