defmodule Topology do
  require Integer

  def create_topology(numNodes, topology, statsPID, module) do
    IO.puts("Topology #{topology} with #{numNodes} nodes")
    nodes = 1..numNodes
    children = nodes
    |> Enum.map(fn i ->
      Supervisor.child_spec({module, [statsPID, i]}, id: {module, i})
    end)
    Supervisor.start_link(children, strategy: :one_for_one, name: NodeSupervisor)

    nodes = Enum.map(Supervisor.which_children(NodeSupervisor), fn child ->
      {_, pid, _, _} = child
      pid
    end)

    nodes = Enum.zip(nodes, 1..numNodes)

    case topology do
      "rand2D" ->
        plist = generate_random_points(numNodes)
        IO.inspect(plist)
        Enum.each(nodes, fn node ->
          get_neighbors(nodes, node, topology, plist)
          |> get_pids_from_indices(nodes)
          |> assign_neighbors(node)
          |> send_neighbors()
        end)
      _ ->
        Enum.each(nodes, fn node ->
          get_neighbors(nodes, node, topology)
          |> get_pids_from_indices(nodes)
          |> assign_neighbors(node)
          |> send_neighbors()
        end)
    end
  end

  defp send_neighbors({cur_node, neighbors}) do
    {neighbors, _} = Enum.unzip(neighbors)
    IO.inspect(neighbors)
    GenServer.cast(cur_node, {:neighbors, neighbors})
  end

  def assign_neighbors(nodes, cur_node) do
    {cur_pid, _} = cur_node
    {cur_pid, nodes}
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "full" do
    {_, nodeIndex} = cur_node
    {_, nodeIndices} = Enum.unzip(nodes)
    nodeIndices |> Enum.reject(fn x -> x == nodeIndex end)
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "line" do
    {_, nodeIndex} = cur_node
    numNodes = Enum.count(nodes)
    cond do
      nodeIndex == 1 -> [nodeIndex + 1]
      nodeIndex == numNodes -> [nodeIndex - 1]
      true -> [nodeIndex - 1, nodeIndex + 1]
    end
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "honeycomb" do
    {_, nodeIndex} = cur_node
    numNodes = Enum.count(nodes)
    get_honeycomb_neighbors(numNodes, nodeIndex)
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "randhoneycomb" do
    {_, nodeIndex} = cur_node
    {_, nodeIndices} = Enum.unzip(nodes)
    numNodes = Enum.count(nodes)
    neighbors = get_honeycomb_neighbors(numNodes, nodeIndex)
    rand_neighbor = nodeIndices
    |> Enum.reject(fn x -> x == nodeIndex end)  # Remove self node
    |> Enum.reject(fn x -> Enum.member?(neighbors, x) end)  # Remove already neighbor nodes
    |> Enum.random()
    [rand_neighbor | neighbors]
  end

  defp get_neighbors(_nodes, cur_node, topology, plist) when topology == "rand2D" do
    {_, nodeIndex} = cur_node
    {x0, y0} = Enum.at(plist, nodeIndex - 1)
    Enum.with_index(plist, 1)
    |> Enum.map(fn {point, index} ->
      if index != nodeIndex do
        {x, y} = point
        if calculate_distance(x0, y0, x, y) <= 0.1 do
          index
        end
      end
    end)
  end

  defp get_honeycomb_neighbors(numNodes, nodeIndex) do
    n = :math.sqrt(numNodes) |> trunc()
    cond do
      # Corner nodes
      nodeIndex == 1 -> [nodeIndex + n]
      nodeIndex == numNodes -> [nodeIndex - 1, nodeIndex - n]

      nodeIndex == n ->
        cond do
          Integer.is_odd(n) -> [nodeIndex - 1, nodeIndex + n]
          Integer.is_even(n) -> [nodeIndex + n]
        end

      nodeIndex == numNodes - n + 1 ->
        cond do
          Integer.is_odd(n) -> [nodeIndex - n]
          Integer.is_even(n) -> [nodeIndex-n, nodeIndex + 1]
        end

      # First row
      nodeIndex < n ->
        cond do
          Integer.is_odd(nodeIndex) -> [nodeIndex - 1, nodeIndex + n]
          Integer.is_even(nodeIndex) -> [nodeIndex + 1, nodeIndex + n]
        end

      # Last row
      nodeIndex > numNodes - n ->
        cond do
          Integer.is_odd(nodeIndex) -> [nodeIndex - 1, nodeIndex - n]
          Integer.is_even(nodeIndex) -> [nodeIndex + 1, nodeIndex - n]
        end

      # First column
      rem(nodeIndex, 2*n) == 1 -> [nodeIndex - n, nodeIndex + n]

      # Last column
      rem(nodeIndex, 2*n) == n ->
        cond do
          Integer.is_odd(n) -> [nodeIndex - 1, nodeIndex - n, nodeIndex + n]
          Integer.is_even(n) -> [nodeIndex - n, nodeIndex + n]
        end

      rem(nodeIndex, 2*n) == 0 ->
        cond do
          Integer.is_odd(n) -> [nodeIndex - n, nodeIndex + n]
          Integer.is_even(n) -> [nodeIndex - 1, nodeIndex - n, nodeIndex + n]
        end

      # All internal nodes
      Integer.is_odd(nodeIndex) ->
        cond do
          Integer.is_odd(n) -> [nodeIndex - 1, nodeIndex - n, nodeIndex + n]
          Integer.is_even(n) -> [nodeIndex + 1, nodeIndex - n, nodeIndex + n]
        end

      Integer.is_even(nodeIndex) ->
        cond do
          Integer.is_odd(n) -> [nodeIndex + 1, nodeIndex - n, nodeIndex + n]
          Integer.is_even(n) -> [nodeIndex - 1, nodeIndex - n, nodeIndex + n]
        end
    end
  end

  defp generate_random_points(numNodes) do
    Enum.map(1..numNodes, fn _ ->
      {:rand.uniform() |> Float.ceil(3), :rand.uniform() |> Float.ceil(3)}
    end)
  end

  defp get_pids_from_indices(neighbors, nodes) do
    Enum.filter(nodes, fn ({_, index}) -> Enum.member?(neighbors, index) end)
  end

 defp calculate_distance(x0, y0, x1, y1) do
    :math.pow(x1-x0, 2) + :math.pow(y1-y0, 2) |> :math.sqrt()
  end

end
