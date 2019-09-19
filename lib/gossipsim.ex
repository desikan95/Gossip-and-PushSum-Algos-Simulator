defmodule Gossipsim do
  use GenServer
  @moduledoc """
  Documentation for Gossipsim.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Gossipsim.hello()
      :world
  added more stuff
  iiiiiiiiiiii
  """

  def buildNodes(numberNodes)do
      nodes= Enum.map((1..numberNodes), fn (x) ->
      pid = createNode()
      mapPIDNodeId(pid,x)
      pid end)
      nodes
  end

  def createNode() do
    {:ok,pid} = GenServer.start_link(__MODULE__,:ok,[])
    pid
  end


  def init(:ok) do
    state = {0,[],0,1}
    {:ok,state} #{NodeId/s,List_of_Neighbours,count,w}
  end

  def mapPIDNodeId(pid,nodeId) do
    GenServer.call(pid,{:mapPIDNodeId,nodeId})
  end

  def handle_call({:mapPIDNodeId,nodeId},_from,state) do
    {id,neighbourList,count,w}=state
    IO.inspect nodeId
    state= {nodeId,neighbourList,count,w}
    IO.inspect(state)
    {:reply,id,state}
  end

  def handle_call({:UpdateNeighbourState,neighbourlist}, _from, state) do
    {id,list,count,w}=state
    state={id,neighbourlist,count,w}
    {:reply,id, state}
  end


  def fullTopology(totalnodes) do
    allnodes=buildNodes(totalnodes)
    Enum.each(allnodes, fn(k) ->
      adjList=[]
      adjList=List.delete(allnodes,k)
      updateNeighbourListState(k,adjList)
      IO.puts("Vertex")
      IO.inspect adjList
    end)
  end

  def updateNeighbourListState(pid,list) do
    GenServer.call(pid, {:UpdateNeighbourState,list})
  end
end

