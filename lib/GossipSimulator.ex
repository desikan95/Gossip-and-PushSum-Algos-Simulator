defmodule GossipSimulator do
  use GenServer
  require Integer


      def main(numNodes,topology,algorithm) do
        IO.puts "Starting application"

        nodes =  case topology do
            "full" -> Topology.buildFullTopology(numNodes)
            "line" -> Topology.buildLineTopology(numNodes)
            "rand2D" -> Topology.buildrand2DTopology(numNodes)
            "3Dtorus" -> Topology.build3DTopology(numNodes)
            "honeycomb" -> Topology.buildHoneycombTopology(numNodes)
            "randhoneycomb" -> Topology.randomHoneyComb(numNodes)
          end
        startAlgorithm(nodes,numNodes,algorithm)

        loop()

      end

      def loop() do
        loop()
      end

      def start_link(x) do
         {:ok, pid} = GenServer.start_link(__MODULE__,x)
         pid
      end

      def init (val) do
        state = {0,[],val,1,0}
        {:ok, state} #id, neighbourList, sum, value
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
        {id,neighbourList,sum,val,_} = GenServer.call(pid, {:printDetails})
        #{sum,val} = GenServer.call(pid, :print_sum )
        IO.puts "\n #{id}"
        IO.inspect pid
        IO.puts "Neighbours are : "
        IO.inspect neighbourList
        IO.puts " Sum and val are #{sum} #{val}"
      end

      def getStartingNode(nodes) when ([]==nodes) do
        []
      end

      def getStartingNode(nodes) do
        pid = Enum.random(nodes)
        case Process.alive?(pid) do
          true -> pid
          false -> getStartingNode(nodes--[pid])
        end
      end

      def handle_cast({:pushsum,sum,val,nodes,startTime},state) do
        {ids,neighbourList,s,w,c} = state
        updateds = s+sum
        updatedw = w+val

        old_ratio = s/w
        new_ratio = updateds/updatedw

        change = abs(new_ratio - old_ratio)




        c  = cond do
          change < :math.pow(10,-10) && c==2  -> count = :ets.update_counter(:table, "count", {2,1})

                                                  if count == nodes do
                                                    endTime = System.monotonic_time(:millisecond) - startTime
                                                    IO.puts "Convergence achieved in  " <> Integer.to_string(endTime) <>" Milliseconds"

                                                    System.stop(1)
                                                  else
                                                    c
                                                  end
          change < :math.pow(10,-10) && c<2   -> c+1
          change > :math.pow(10,-10)          -> 0
          true -> c
        end




        updatedstate = {ids,neighbourList,updateds/2,updatedw/2,c}

        randomNode = Enum.random(neighbourList)

        #continuePushSum(randomNode,updateds/2,updatedw/2,nodes,startTime)
        GenServer.cast(randomNode,{:pushsum,s,w,nodes,startTime})


        {:noreply, updatedstate}
      end

      def handle_cast({:gossip,nodes,startTime},state) do
        {ids,neighbourList,s,w,c} = state
        neighbour = Enum.random(neighbourList)
        if (c==10) do
              #  count = :ets.update_counter(:gossiptable, "totalnodecounter", {2,1})
                 count = :ets.update_counter(:table, "count", {2,1})
                if (count==nodes) do
                  endTime = System.monotonic_time(:millisecond) - startTime
                  IO.puts "Convergence achieved in  " <> Integer.to_string(endTime) <>" Milliseconds"
                  System.stop(1)
                end
        end
        GenServer.cast(neighbour,{:gossip,nodes,startTime})
        {:noreply,{ids,neighbourList,s,w,c+1}}
      end


      def handle_call({:mapID, nodeID},_from, state) do
        {id, neighbourList, s, w,c} = state
        state = {nodeID, neighbourList, s, w,c}
        {:reply, id, state}
      end

      def handle_call({:updateNeighbourList, list},_from, state) do
        {id, _ , s , w,c} = state
        state = {id, list, s, w,c}
        {:reply, id, state}
      end

      def handle_call({:addNeighbourList, list},_from, state) do
        {id, oldlist , s , w,c} = state
        state = {id, [list|oldlist], s, w,c}
        {:reply, id, state}
      end

      def handle_call({:printDetails},_from, state) do
        {:reply, state, state}
      end

      def printTopology(nodeIDs) do
        Enum.each(nodeIDs, fn(x) -> print(x) end)
      end


    def createCountTable() do
      table = :ets.new(:gossiptable, [:named_table,:public])
          :ets.insert(table, {"totalnodecounter",0})
    end

    def startAlgorithm(nodes,numNodes,algo) do

          startTime = System.monotonic_time(:millisecond)
          table = :ets.new(:table, [:named_table,:public])
              :ets.insert(table, {"count",0})
          createCountTable()


          startingnode = Enum.random(nodes)
          case algo do
            "push-sum" -> GenServer.cast(startingnode,{:pushsum,1,1,numNodes,startTime})
            "gossip" ->   GenServer.cast(startingnode,{:gossip,numNodes,startTime})
          end

     end


  end
