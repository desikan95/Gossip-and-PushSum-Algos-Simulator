defmodule PushSumWorker do
  use GenServer
  require Integer

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
    #GenServer.cast(pid, {:updateNeighbourList,list})
  end

  def addNeighbours(pid,list) do
    GenServer.call(pid,{:addNeighbourList,list})
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

  def handle_call({:addNeighbourList, list},_from, state) do
    {id, oldlist , s , w} = state
    state = {id, [list|oldlist], s, w}
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
    nodes = buildHoneycombTopology(numNodes)
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

  def handle_cast({:newupdateNeighbourList,list},state) do
    {id, _, s ,w} = state
    state = { id , list, s, w}
    {:noreply,state}
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
  #  IO.inspect nodes
    #{0,0,0,pid}=nodes
    #IO.inspect pid
    Enum.each(nodes, fn(node)->
                                    list = Tuple.to_list(node)
                                    #IO.inspect node
                                    len = edgelen
                                    {x,y,z,pid} = node
                                    xneighbours = cond do
                                                    x==0 -> [{1,y,z},{len,y,z}]
                                                    x==len -> [{x-1,y,z},{0,y,z}]
                                                    true -> [{x-1,y,z},{x+1,y,z}]
                                                  end
                                    yneighbours = cond do
                                                    y==0 -> [{x,len,z},{x,y+1,z}]
                                                    y==len -> [{x,y-1,z},{x,0,z}]
                                                    true -> [{x,y-1,z},{x,y+1,z}]
                                                  end
                                    zneighbours = cond do
                                                    z==0 -> [{x,y,z+1},{x,y,len}]
                                                    z==len -> [{x,y,z-1},{x,y,0}]
                                                    true -> [{x,y,z-1},{x,y,z+1}]
                                                  end

                              #      IO.puts "\n\nNeighbours for #{x} #{y} #{z}  "
                              #      IO.inspect pid
                                    neighbourlist =[zneighbours|[yneighbours|xneighbours]] |> List.flatten
                              #      IO.inspect neighbourlist
                              #      IO.puts "\nEnd"

                                    neighbourPIDs = Enum.map(nodes, fn(node)->
                                                                {x,y,z,pid} = node

                                                                value = Enum.filter(neighbourlist, fn(neighbour) ->
                                                                                                            {x,y,z}==neighbour
                                                                                            end)
                                                                if !([] == value) do
                                                                  pid
                                                                end


                                                      end)
                                                      |> Enum.reject(fn(x) -> x==:nil end)



                              #      IO.inspect neighbourPIDs
                                    case numNodes do
                                      8 -> updateNeighbours(pid,[neighbourPIDs|neighbourPIDs] |> List.flatten )
                                      _ -> updateNeighbours(pid,neighbourPIDs)
                                    end
                                  #  updateNeighbours(pid,neighbourPIDs)

                        end)
      printTopology(proc)

      proc
  end

  def buildHoneycombTopology(numNodes) do
    nodes = buildNodes(numNodes)
    IO.inspect nodes
    nodemap = Enum.reduce(nodes,%{}, fn(node,acc) ->  {id, _,_,_} = GenServer.call(node, {:printDetails})
                                                      Map.put(acc, id, node)
                                     end)
    IO.inspect nodemap
    nodelist = Enum.reduce(numNodes..1,[], fn x,acc -> [x|acc] end) |> Enum.chunk_every(6)
    IO.inspect nodelist,charlists: :as_lists

    nodelist
    |> Enum.with_index
    |> Enum.each(fn ({node, i}) ->
                                IO.puts "#{i} : "

                                cond do
                                  Integer.is_odd(i) -> node
                                                       |> Enum.with_index(1)
                                                       |> Enum.map (fn ({x,j}) ->
                                                                                  list = cond do
                                                                                            Integer.is_even(j) -> [x-1,x+6,x-6]
                                                                                            Integer.is_odd(j) -> [x+1,x+6,x-6]
                                                                                         end
                                                                                  IO.inspect "List for #{x} is "
                                                                                  IO.inspect list,charlists: :as_lists
                                                                                  listpids = Enum.map(list,fn(x)->
                                                                                                                    if Map.has_key?(nodemap,x)
                                                                                                                      do Map.get(nodemap,x) end
                                                                                                                   end)
                                                                                             |> Enum.reject(fn(x) -> x==:nil end)
                                                                                  IO.inspect listpids
                                                                                  pid = Map.get(nodemap,x)
                                                                                  updateNeighbours(pid,listpids)
                                                                      end)


                                  Integer.is_even(i) -> case i do
                                                            0 ->   node
                                                                   |> Enum.with_index(1)
                                                                   |> Enum.map (fn ({x,j}) ->
                                                                                            list = cond do
                                                                                                      j==1 -> [x+6]
                                                                                                      j==6 -> [x+6]
                                                                                                      Integer.is_even(j) -> [x+1,x+6]
                                                                                                      Integer.is_odd(j) -> [x-1,x+6]
                                                                                                   end
                                                                                            IO.inspect "List for #{x} is "
                                                                                            IO.inspect list,charlists: :as_lists
                                                                                            listpids = Enum.map(list,fn(x)-> if Map.has_key?(nodemap,x)
                                                                                                                                do Map.get(nodemap,x) end
                                                                                                                              end)
                                                                                                       |> Enum.reject(fn(x) -> x==:nil end)
                                                                                            IO.inspect listpids
                                                                                            pid = Map.get(nodemap,x)
                                                                                            updateNeighbours(pid,listpids)
                                                                                  end)

                                                            _ ->  node
                                                                  |> Enum.with_index(1)
                                                                  |> Enum.map (fn ({x,j}) ->
                                                                                            list = cond do
                                                                                                      j==1 -> [x+6,x-6]
                                                                                                      j==6 -> [x+6,x-6]
                                                                                                      Integer.is_even(j) -> [x+1,x+6,x-6]
                                                                                                      Integer.is_odd(j) -> [x-1,x+6,x-6]
                                                                                                   end
                                                                                            IO.inspect "List for #{x} is "
                                                                                            IO.inspect list,charlists: :as_lists
                                                                                            listpids = Enum.map(list,fn(x)->
                                                                                                                              if Map.has_key?(nodemap,x)
                                                                                                                                do Map.get(nodemap,x) end
                                                                                                                             end)
                                                                                                       |> Enum.reject(fn(x) -> x==:nil end)
                                                                                            IO.inspect listpids
                                                                                            pid = Map.get(nodemap,x)
                                                                                            updateNeighbours(pid,listpids)
                                                                                  end)
                                                        end

                                end

                end)


#    nodeIDs = Enum.map(nodes, fn(node) -> {id,neighbourList,sum,val} = GenServer.call(node, {:printDetails})
#                                            id
#                       end)
#    IO.inspect nodeIDs


      printTopology(nodes)

      nodes
  end

  def randomHoneyComb(numNodes) do
    nodes = buildHoneycombTopology(numNodes)

    Enum.each(nodes, fn(node)->
      randNeighbour = Enum.random(nodes)
      IO.puts "Adding random guy "
      IO.inspect randNeighbour
      addNeighbours(node,randNeighbour)
    end)

      printTopology(nodes)

      nodes
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
