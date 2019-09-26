defmodule Gossipsim do
  use GenServer
  @moduledoc """
  Documentation for Gossipsim.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Gossipsim.hello()
      :world WHAT THE

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
    #IO.inspect nodeId
    state= {nodeId,neighbourList,count,w}
    #IO.inspect(state)
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
      #IO.puts("Vertex")
      #IO.inspect adjList
    end)
    allnodes
  end

  def createCountTable() do
    table = :ets.new(:table, [:named_table,:public])
        :ets.insert(table, {"count",0})
  end

  def updateNeighbourListState(pid,list) do
    GenServer.call(pid, {:UpdateNeighbourState,list})
  end


  def startGossip(allNodes, startTime) do
    chosenFirstNode = Enum.random(allNodes)
    updateCountState(chosenFirstNode, startTime, length(allNodes))
    recurseGossip(chosenFirstNode, startTime, length(allNodes))
  end

  def recurseGossip(chosenRandomNode, startTime, totalnodes) do
    myCount = getCountState(chosenRandomNode)
    cond do
      myCount < 11 ->
        adjacentList = getNeighbourList(chosenRandomNode)
        chosenRandomAdjacent=Enum.random(adjacentList)
        Task.start(Gossipsim,:receiveMessage,[chosenRandomAdjacent, startTime, totalnodes])
        recurseGossip(chosenRandomNode, startTime, totalnodes)
      true ->
        Process.exit(chosenRandomNode, :normal)
    end
      recurseGossip(chosenRandomNode, startTime, totalnodes)
  end

  def receiveMessage(pid, startTime, total) do
    updateCountState(pid, startTime, total)
    recurseGossip(pid, startTime, total)
  end
  def getCountState(pid) do
    GenServer.call(pid,{:GetCountState})
  end

  def getNeighbourList(pid) do
    GenServer.call(pid,{:GetAdjacentList})
  end

  def updateCountState(pid, startTime, totalnodes) do
    GenServer.call(pid, {:UpdateCountState,startTime, totalnodes})
end

  def handle_call({:GetAdjacentList}, _from ,state) do
    {id,list,count,w}=state
    {:reply,list, state}
  end

  def handle_call({:GetCountState}, _from ,state) do
    {id,list,count,w}=state
    {:reply,count, state}
  end

def handle_call({:UpdateCountState,startTime, totalnodes}, _from,state) do
  {id,list,count,w}=state
  if(count==0) do
    count = :ets.update_counter(:table, "count", {2,1})
    if(count == totalnodes) do
      endTime = System.monotonic_time(:millisecond) - startTime
      IO.puts endTime
      IO.puts "Convergence achieved in = #{endTime} Milliseconds"
      System.halt(1)
    end
  end
  state={id,list,count+1,w}
  {:reply, count+1, state}
end

def gossip(numberNodes) do
  nodes=fullTopology(numberNodes)
  createCountTable()
  startTime = System.monotonic_time(:millisecond)
  IO.puts startTime
  startGossip(nodes, startTime)
end
end

