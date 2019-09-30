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
    nodes = startPushSumFor2D(numNodes)
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

  def nextList([]) do
    IO.puts "List parsed"
  end

  def nextList([head|tail]) do

    case tail do

      [elem,next|_] ->
                  #IO.puts "Element is #{elem} Tail : #{next} Prev : #{head}"
                  neighbourList = [head,next]
                  updateNeighbours(elem, neighbourList)
                  nextList(tail)
      _ -> IO.puts "Lists parsed"
    end


  end




  def buildLineTopology(numNodes) do
    nodes = buildNodes(numNodes)
    first_node = Enum.at(nodes,0)
    last_node = Enum.at(nodes,numNodes-1)
    updateNeighbours(first_node, [Enum.at(nodes,1)])
    updateNeighbours(last_node, [Enum.at(nodes,numNodes-2)])
    nextList(nodes)
    printTopology(nodes)

    nodes
  end

  def startPushSumFor2D(numNodes) do
    nodes = buildRandom2DTopology(numNodes)
    pointers = Enum.map(nodes, fn(x) -> {_,neighbourList,_,_} = GenServer.call(x, {:printDetails})
                                          if Enum.empty?(neighbourList) == false do
                                                x
                                          end
                                      end)
                 |> Enum.reject(fn(x) -> x==:nil end)

    IO.puts "Pointers "
    IO.inspect pointers

    pointers
    #GenServer.cast(pid,{:initial_start})
  end

  def distance(a,b) do
    x1 = Enum.at(a,0)
    x2 = Enum.at(b,0)
    y1 = Enum.at(a,1)
    y2 = Enum.at(b,1)
    num1 = :math.pow(x2-x1,2)
    num2 = :math.pow(y2-y1,2)
    dist = :math.sqrt(num1+num2)
    #IO.puts "Distance between #{x1},#{y1} and #{x2},#{y2} is #{dist}"
    dist<0.1
  end

  def buildRandom2DTopology(numNodes) do
    nodes = buildFullTopology(numNodes)
    points = Enum.map(nodes, fn(item) -> {_,neighbourList,_,_} = GenServer.call(item, {:printDetails})
                                      x = :rand.uniform() |> Float.round(7)
                                      y = :rand.uniform() |> Float.round(7)
                                      [x,y,item,neighbourList]
                                      end)

    Enum.each(points, fn (point) -> [x,y,pointID,neighbourList] = point
                                    IO.puts "\n\nFor point"
                                    IO.inspect pointID

                                    newNeighbours = Enum.map(neighbourList, fn (neighbour) ->
                                                        position = Enum.filter(points, fn(item) ->   [_,_,pid,_] = item
                                                                           pid==neighbour
                                                                           end)
                                                                   |> Enum.reduce([],fn (item,pos)-> [x,y,_,_] = item
                                                                           pos ++ [x,y]
                                                                         end)
                                                          if distance([x,y], position) do
                                                              [neighbour]
                                                          end

                                                    end)
                                                    |> Enum.reject(fn(x) -> x==:nil end)
                                                    |> List.flatten
                                      updateNeighbours(pointID,newNeighbours)


                                        IO.puts "New neighbour for "
                                        IO.inspect pointID
                                        IO.puts "is "
                                        IO.inspect newNeighbours
                                        IO.puts "\n\n"

                                    end)

    IO.puts "Comparisons are over"
    printTopology(nodes)

    IO.puts "printing list of nodes"
    IO.inspect nodes

  #  pointerss = Enum.map(nodes, fn(x) -> {_,neighbourList,_,_} = GenServer.call(x, {:printDetails})
  #                                      if Enum.empty?(neighbourList) == false do
  #                                            x
  #                                      end
  #                                  end)
    IO.puts "Printing pointerss"
  #  printTopology(pointerss)

    nodes
  end

  def build3DTopology(numNodes) do

    cuberoot =  1..numNodes |> Enum.map( fn (x) -> if (x*x*x == numNodes) do
                                          x
                                        end end)
                            |> Enum.reject(fn(x) -> x==:nil end)
    edgelen = Enum.at(cuberoot,0)-1
    positions = Enum.map(0..edgelen, fn(x) ->
                                                Enum.map(0..edgelen, fn(y) ->
                                                                                Enum.map(0..edgelen, fn(z) ->
                                                                                                                {x,y,z}
                                                                                end)
                                                end)
                                      end)
                |> List.flatten
    proc = buildNodes(numNodes)
    nodes = Enum.map(0..(numNodes-1), fn(i) ->
                                 Tuple.append(Enum.at(positions,i), Enum.at(proc,i))
                          end )
    IO.inspect nodes
    #{0,0,0,pid}=nodes
    #IO.inspect pid
    Enum.each(nodes, fn(node)->
                                    list = Tuple.to_list(node)
                                    #IO.inspect node
                                    len = edgelen
                                    case node do
                                        {0,0,0,pid} -> IO.puts "Outer node"
                                                       IO.inspect pid
                                        {0,0,x,pid} when x==edgelen -> IO.puts "Outer node"
                                                       IO.inspect pid
                                        {0,x,0,pid} when x==edgelen-> IO.puts "Outer node"
                                                       IO.inspect pid
                                        {0,x,x,pid} when x==edgelen -> IO.puts "Outer node"
                                                       IO.inspect pid
                                       {x,0,0,pid} when x==edgelen -> IO.puts "Outer node"
                                                      IO.inspect pid
                                       {x,0,x,pid} when x==edgelen  -> IO.puts "Outer node"
                                                      IO.inspect pid
                                       {x,x,0,pid} when x==edgelen  -> IO.puts "Outer node"
                                                      IO.inspect pid
                                       {x,x,x,pid} when x==edgelen  -> IO.puts "Outer node"
                                                      IO.inspect pid

                                      _ -> #IO.puts "Not found now"
                                    end
                                    #IO.inspect pid
                        end)


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
