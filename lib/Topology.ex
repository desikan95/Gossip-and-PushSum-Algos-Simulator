defmodule Topology do
  import GossipSimulator
  require Integer

  def buildFullTopology(numNodes) do
    nodes = buildNodes(numNodes)
    Enum.each(nodes, fn(x) ->
                              neighbourList = List.delete(nodes,x)
                              updateNeighbours(x, neighbourList)
                            end)
    nodes
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


    nodes
  end

  def  buildrand2DTopology(numNodes) do
    nodes = buildRandom2DTopology(numNodes)
    pointers = Enum.map(nodes, fn(x) -> {_,neighbourList,_,_,_} = GenServer.call(x, {:printDetails})
                                          if Enum.empty?(neighbourList) == false do
                                                x
                                          end
                                      end)
                 |> Enum.reject(fn(x) -> x==:nil end)

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
    abs(dist)<0.1

  end

  def buildRandom2DTopology(numNodes) do
    nodes = buildFullTopology(numNodes)
    points = Enum.map(nodes, fn(item) -> {_,neighbourList,_,_,_} = GenServer.call(item, {:printDetails})
                                      x = :rand.uniform() |> Float.round(7)
                                      y = :rand.uniform() |> Float.round(7)
                                      [x,y,item,neighbourList]
                                      end)

    Enum.each(points, fn (point) -> [x,y,pointID,neighbourList] = point


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

                                    end)




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
      #printTopology(proc)

      proc
  end

  def buildHoneycombTopology(numNodes) do
    nodes = buildNodes(numNodes)

    nodemap = Enum.reduce(nodes,%{}, fn(node,acc) ->  {id, _,_,_,_} = GenServer.call(node, {:printDetails})
                                                      Map.put(acc, id, node)
                                     end)

    nodelist = Enum.reduce(numNodes..1,[], fn x,acc -> [x|acc] end) |> Enum.chunk_every(6)


    nodelist
    |> Enum.with_index
    |> Enum.each(fn ({node, i}) ->


                                cond do
                                  Integer.is_odd(i) -> node
                                                       |> Enum.with_index(1)
                                                       |> Enum.map (fn ({x,j}) ->
                                                                                  list = cond do
                                                                                            Integer.is_even(j) -> [x-1,x+6,x-6]
                                                                                            Integer.is_odd(j) -> [x+1,x+6,x-6]
                                                                                         end

                                                                                  listpids = Enum.map(list,fn(x)->
                                                                                                                    if Map.has_key?(nodemap,x)
                                                                                                                      do Map.get(nodemap,x) end
                                                                                                                   end)
                                                                                             |> Enum.reject(fn(x) -> x==:nil end)

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

                                                                                            listpids = Enum.map(list,fn(x)-> if Map.has_key?(nodemap,x)
                                                                                                                                do Map.get(nodemap,x) end
                                                                                                                              end)
                                                                                                       |> Enum.reject(fn(x) -> x==:nil end)

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

                                                                                            listpids = Enum.map(list,fn(x)->
                                                                                                                              if Map.has_key?(nodemap,x)
                                                                                                                                do Map.get(nodemap,x) end
                                                                                                                             end)
                                                                                                       |> Enum.reject(fn(x) -> x==:nil end)

                                                                                            pid = Map.get(nodemap,x)
                                                                                            updateNeighbours(pid,listpids)
                                                                                  end)
                                                        end

                                end

                end)


    #  printTopology(nodes)

      nodes
  end

  def randomHoneyComb(numNodes) do
    nodes = buildHoneycombTopology(numNodes)

    Enum.each(nodes, fn(node)->
      randNeighbour = Enum.random(nodes)
      addNeighbours(node,randNeighbour)
    end)

    #  printTopology(nodes)

      nodes
  end

end
