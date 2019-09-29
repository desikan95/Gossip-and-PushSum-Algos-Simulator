defmodule PushSumWorker do
  use GenServer

  def start_link(x) do
     {:ok, pid} = GenServer.start_link(__MODULE__,x)
     pid
  end

  def buildNodes(numberNodes)do
      nodes= Enum.map((1..numberNodes), fn (x) ->
      pid = start_link(x)
      mapPIDNodeId(pid,x)
      pid end)
      nodes
  end

  def mapPIDNodeId(pid,nodeID) do
    GenServer.call(pid, {:mapID,nodeID})
  end

  def updateNeighbours(pid, list) do
    GenServer.call(pid, {:updateNeighbourList, list})
  end

  def print(pid) do
    {id,neighbourList,sum,val} = GenServer.call(pid, {:printDetails})
    #{sum,val} = GenServer.call(pid, :print_sum )
    IO.puts "\n #{id}"
    IO.inspect pid
    IO.puts "Neighbours are : "
    IO.inspect neighbourList
    IO.puts " Sum and val are #{sum} #{val}"
  end

  def handle_call({:mapID, nodeID},_from, state) do
    {id, neighbourList, s, w} = state
    state = {nodeID, neighbourList, s, w}
    {:reply, id, state}
  end

  def handle_call({:updateNeighbourList, list},_from, state) do
    {id, _ , s , w} = state
    state = {id, list, s, w}
    {:reply, id, state}
  end

  def handle_call({:printDetails},_from, state) do

    {:reply, state, state}
  end

  def printTopology(nodeIDs) do
    Enum.each(nodeIDs, fn(x) -> print(x) end)
  end

  def buildFullTopology(numNodes) do
    nodes = buildNodes(numNodes)
    Enum.each(nodes, fn(x) ->
                              neighbourList = List.delete(nodes,x)
                              updateNeighbours(x, neighbourList)
                            end)
    printTopology(nodes)
    nodes
  end

  def startPushSum(numNodes) do
    nodes = buildFullTopology(numNodes)
    pid = Enum.random(nodes)
    IO.puts "Starting at "
    IO.inspect pid
    pushSumBroadcast(pid, 3)
    #GenServer.cast(pid,{:initial_start})
  end

  def handle_cast({:initial_start},state) do
    {id, neighbourList, s, w} = state
    friend = Enum.random(neighbourList)
    GenServer.cast(friend,{:push_sum_broadcast,s/2,w/2})
    state = {id, neighbourList, s/2, w/2}
    {:noreply, state}
  end

  def pushSumBroadcast(node, count) when (count==0) do
    IO.puts "Limit reached for "
    IO.inspect node
    Process.exit(node, :kill)
  end

  def pushSumBroadcast(node,count) when (count>=0) do
    {id,list,s,w}=GenServer.call(node, {:printDetails})
    GenServer.cast(node,{:save_current_state}) #Updates current state by changing s and w to half its original. Remaining goes to friend.

    friend = Enum.random(list)
    old_estimate = GenServer.call(friend, {:get_sum_estimate})



    GenServer.cast(friend,{:push_sum_broadcast,s/2,w/2})
    new_estimate = GenServer.call(friend, {:get_sum_estimate})

    change = abs(new_estimate - old_estimate)
    IO.puts "Change is #{change}"
    val = :math.pow(10,-10)
    IO.puts "Pow value is #{val}"
  #  if (change < :math.pow(10,-10))
  #    do  IO.puts "Friend has converged"
  #  end

    cond do
      change < :math.pow(10,-10) -> pushSumBroadcast(friend, count-1)
      true -> pushSumBroadcast(friend, count)
    end


    #pushSumBroadcast(friend,count+1)
  end

  def handle_call({:get_sum_estimate},_from, state) do
    {_,_,s,w} = state
    {:reply, s/w,state}
  end

  def handle_cast({:save_current_state},state) do
    {id, neighbourList, s, w} = state
    state = {id, neighbourList,s/2, w/2}
    {:noreply, state}
  end


  def handle_cast({:push_sum_broadcast,s,w},state) do

    {id, neighbourList, old_s, old_w} = state
    state = {id, neighbourList, old_s+s, old_w+w}
    {:noreply, state}
  end



  def buildLineTopology(numNodes) do
    nodes = buildNodes(numNodes)

    list = [1,2,3,4,5]
  #  a = Enum.at(list, 0)
  #  b = Enum.at(list, 4)
    [1,succ|_] = list


    #list = a
    #[succ | a] = a




    #IO.puts " #{x} #{a} #{b} "
    #Enum.each(nodes, fn(x) -> neighbourList = List.)
  end


  def init (val) do

    sum = 1
    value = 1
    state = {0,[],val,1}
    {:ok, state} #id, neighbourList, sum, value
  end


end

defmodule PushSumSupervisor do
  use DynamicSupervisor

  def start_link(:no_args) do
    DynamicSupervisor.start_link(__MODULE__, :no_args,name: __MODULE__)
  #  add_worker(:no_args)
  end

  def init(:no_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def add_worker(x) do

     val = Kernel.inspect(x)
     IO.puts "Val is #{val}"
     child_spec = Supervisor.child_spec({PushSumWorker,x},id: val)

     child_spec_map = %{
        id: val,
        start: {PushSumWorker,:start_link,[val]}
     }
     {:ok, pid } = DynamicSupervisor.start_child(__MODULE__,child_spec_map)
     IO.inspect pid
     PushSumWorker.print(pid)


  end

  def hello_worker() do
    IO.puts "hey"
  end

end

defmodule MainMod do
  use GenServer

  def start_link(count) do
    GenServer.start_link(__MODULE__, count)
  end

  def init(count) do
    Process.send_after(self(), :kickoff, 0)
    {:ok, count}
  end

  def handle_info(:kickoff, count) do
    PushSumSupervisor.start_link(:no_args);
    1..count |> Enum.each ( fn (x) -> PushSumSupervisor.add_worker(x) end)
    {:noreply, count}
  end
end
