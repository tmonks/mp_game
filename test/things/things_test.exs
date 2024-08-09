defmodule MPG.ThingsTest do
  use ExUnit.Case

  alias MPG.Things
  alias MPG.Things.Player
  alias MPG.Things.State

  test "new/1 creates a new state with the given title" do
    assert %State{topic: "foo", players: []} = Things.new("foo")
  end

  test "add_player/2 adds a player to the state" do
    state = Things.new("foo")
    assert %State{topic: "foo", players: [%Player{name: "Joe"}]} = Things.add_player(state, "Joe")
  end

  test "set_player_answer/3 sets the current_answer for the specified player" do
    state =
      Things.new("foo")
      |> Things.add_player("Joe")
      |> Things.add_player("Jane")

    assert %State{players: players} = Things.set_player_answer(state, "Joe", "banana")
    assert [jane, joe] = Enum.sort_by(players, & &1.name)
    assert joe == %Player{name: "Joe", current_answer: "banana"}
    assert jane == %Player{name: "Jane", current_answer: nil}
  end
end
