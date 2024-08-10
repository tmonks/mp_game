defmodule MPG.ThingsTest do
  use ExUnit.Case

  alias MPG.Things
  alias MPG.Things.Player
  alias MPG.Things.State

  test "new/1 creates a new state with the given title" do
    assert %State{topic: "foo", players: []} = Things.new("foo")
  end

  test "new_question/2 resets the topic and player answers" do
    state = %State{
      topic: "Things that are red",
      players: [
        %Player{name: "Joe", current_answer: "apple"},
        %Player{name: "Jane", current_answer: "strawberry"}
      ]
    }

    assert %State{topic: "Things that are blue", players: players} =
             Things.new_question(state, "Things that are blue")

    assert [jane, joe] = Enum.sort_by(players, & &1.name)
    assert jane == %Player{name: "Jane", current_answer: nil}
    assert joe == %Player{name: "Joe", current_answer: nil}
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
