defmodule Topology do
  require Integer

  def create_topology(num_of_nodes, topology, statsPID, module, failure_prob) do
    IO.puts("Creating topology")
    nodes = 1..num_of_nodes
    children = nodes
    |> Enum.map(fn i ->
      Supervisor.child_spec({module, [statsPID, i, failure_prob]}, id: {module, i})
    end)
    Supervisor.start_link(children, strategy: :one_for_one, name: NodeSupervisor)

    nodes = Enum.map(Supervisor.which_children(NodeSupervisor), fn child ->
      {_, pid, _, _} = child
      pid
    end)

    nodes = Enum.zip(nodes, 1..num_of_nodes)

    case topology do
      "rand2d" ->
        plist = generate_random_points(num_of_nodes)
        Enum.each(nodes, fn node ->
          get_neighbors(nodes, node, topology, plist)
          |> get_pids_from_indices(nodes)
          |> assign_neighbors(node)
          |> send_neighbors()
        end)
      "3dtorus" ->
        arr_3d = get_3d_arr(num_of_nodes)
        Enum.each(nodes, fn node ->
          get_neighbors(nodes, node, topology, arr_3d)
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
    GenServer.cast(cur_node, {:neighbors, neighbors})
  end

  defp assign_neighbors(nodes, cur_node) do
    {cur_pid, _} = cur_node
    {cur_pid, nodes}
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "full" do
    {_, nodeIndex} = cur_node
    {_, nodeIndices} = Enum.unzip(nodes)
    # IO.puts("neighbors node #{nodeIndex}")
    nodeIndices |> Enum.reject(fn x -> x == nodeIndex end)
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "line" do
    {_, nodeIndex} = cur_node
    num_of_nodes = Enum.count(nodes)
    # IO.puts("neighbors node #{nodeIndex} / #{num_of_nodes}")
    cond do
      nodeIndex == 1 -> [nodeIndex + 1]
      nodeIndex == num_of_nodes -> [nodeIndex - 1]
      true -> [nodeIndex - 1, nodeIndex + 1]
    end
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "honeycomb" do
    {_, nodeIndex} = cur_node
    num_of_nodes = Enum.count(nodes)
    # IO.puts("neighbors node #{nodeIndex} / #{num_of_nodes}")
    get_honeycomb_neighbors(num_of_nodes, nodeIndex)
  end

  defp get_neighbors(nodes, cur_node, topology) when topology == "randhoneycomb" do
    {_, nodeIndex} = cur_node
    {_, nodeIndices} = Enum.unzip(nodes)
    num_of_nodes = Enum.count(nodes)
    # IO.puts("neighbors node #{nodeIndex} / #{num_of_nodes}")
    neighbors = get_honeycomb_neighbors(num_of_nodes, nodeIndex)
    rand_neighbor = nodeIndices
    |> Enum.reject(fn x -> x == nodeIndex end)  # Remove self node
    |> Enum.reject(fn x -> Enum.member?(neighbors, x) end)  # Remove already neighbor nodes
    |> Enum.random()
    [rand_neighbor | neighbors]
  end

  defp get_neighbors(_nodes, cur_node, topology, plist) when topology == "rand2d" do
    {_, nodeIndex} = cur_node
    # IO.puts("neighbors node #{nodeIndex}")
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

  defp get_neighbors(nodes, cur_node, topology, arr) when topology == "3dtorus" do
    {_, nodeIndex} = cur_node
    num_of_nodes = Enum.count(nodes)
    n = ceil(:math.pow(num_of_nodes, 1/3))
    {i, j, k} = {
      div(nodeIndex-1, (n*n)),
      div(rem(nodeIndex-1, n*n), n),
      rem(nodeIndex-1, n)
    }
    cond do
      nodeIndex == num_of_nodes ->
        [
          Enum.at(arr, n-1) |> Enum.at(n-1) |> Enum.at(rem(n-2,n)),
          Enum.at(arr, n-1) |> Enum.at(n-1) |> Enum.at(rem(n,n)),
          Enum.at(arr, n-1) |> Enum.at(rem(n-2,n)) |> Enum.at(n-1),
          Enum.at(arr, n-1) |> Enum.at(rem(n,n)) |> Enum.at(n-1),
          Enum.at(arr, rem(n-2,n)) |> Enum.at(n-1) |> Enum.at(n-1),
          Enum.at(arr, rem(n,n)) |> Enum.at(n-1) |> Enum.at(n-1)
        ]
      true ->
        [
          Enum.at(arr, i) |> Enum.at(j) |> Enum.at(rem(k - 1, n)),
          Enum.at(arr, i) |> Enum.at(j) |> Enum.at(rem(k + 1, n)),
          Enum.at(arr, i) |> Enum.at(rem(j - 1, n)) |> Enum.at(k),
          Enum.at(arr, i) |> Enum.at(rem(j + 1, n)) |> Enum.at(k),
          Enum.at(arr, rem(i - 1, n)) |> Enum.at(j) |> Enum.at(k),
          Enum.at(arr, rem(i + 1, n)) |> Enum.at(j) |> Enum.at(k)
        ]
    end
  end

  defp get_honeycomb_neighbors(num_of_nodes, nodeIndex) do
    n = :math.sqrt(num_of_nodes) |> trunc()
    cond do
      # Corner nodes
      nodeIndex == 1 -> [nodeIndex + n]
      nodeIndex == num_of_nodes -> [nodeIndex - 1, nodeIndex - n]

      nodeIndex == n ->
        cond do
          Integer.is_odd(n) -> [nodeIndex - 1, nodeIndex + n]
          Integer.is_even(n) -> [nodeIndex + n]
        end

      nodeIndex == num_of_nodes - n + 1 ->
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
      nodeIndex > num_of_nodes - n ->
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

  defp generate_random_points(num_of_nodes) do
    Enum.map(1..num_of_nodes, fn _ ->
      {:rand.uniform() |> Float.ceil(3), :rand.uniform() |> Float.ceil(3)}
    end)
  end

  defp get_3d_arr(num_of_nodes) do
    n = ceil(:math.pow(num_of_nodes, 1/3))

    Enum.map(1..num_of_nodes, fn x -> x end)
      |> Enum.chunk_every(n*n)
      |> Enum.map(fn x -> Enum.chunk_every(x, n) end)
  end

  defp get_pids_from_indices(neighbors, nodes) do
    Enum.filter(nodes, fn ({_, index}) -> Enum.member?(neighbors, index) end)
  end

 defp calculate_distance(x0, y0, x1, y1) do
    :math.pow(x1-x0, 2) + :math.pow(y1-y0, 2) |> :math.sqrt()
  end

end
