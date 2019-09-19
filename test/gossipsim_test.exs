defmodule GossipsimTest do
  use ExUnit.Case
  doctest Gossipsim

  test "greets the world" do
    assert Gossipsim.hello() == :world
  end
end
