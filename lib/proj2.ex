defmodule Proj2 do
  @moduledoc """
  Documentation for Gossip.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Gossip.hello()
      :world

  """

  def main(args) do
    # try do
      [numNodes, topology, algorithm] = args |> parse_input
      numNodes = round_up(numNodes, topology)
      {:ok, statsPID} = GenServer.start_link(Stats, [numNodes])
      Topology.create_topology(numNodes, topology, statsPID)
      {_, pid, _, _} = Supervisor.which_children(GossipSupervisor) |> Enum.random
      GenServer.call(statsPID, :startTimer)
      GenServer.cast(pid, {:gossip, "psst"})
      loop()
    # rescue
    #   FunctionClauseError -> IO.puts("3 arguments expected - numNodes(int) topology algorithm")
    #   ArgumentError -> IO.puts("3 arguments expected - numNodes(int) topology algorithm")
    # end
  end

  def parse_input([numNodes, topology, algorithm]) do
    [String.to_integer(numNodes), topology, algorithm]
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
