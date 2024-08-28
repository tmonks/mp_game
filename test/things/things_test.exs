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

  test "add_player/3 adds a player to the state" do
    state = Things.new("foo")
    id = UUID.uuid4()

    assert %State{topic: "foo", players: [player]} = Things.add_player(state, id, "Joe")
    assert player.name == "Joe"
    assert player.id == id
  end

  test "set_player_answer/3 sets the current_answer for the specified player" do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.add_player(jane_id, "Jane")

    assert %State{players: players} = Things.set_player_answer(state, joe_id, "banana")
    assert %Player{name: "Joe", current_answer: "banana"} = Enum.find(players, &(&1.id == joe_id))
    assert %Player{name: "Jane", current_answer: nil} = Enum.find(players, &(&1.id == jane_id))
  end

  test "get_player/1 retrieves the player with the given id" do
    state = Things.new("foo")
    id = UUID.uuid4()

    state = Things.add_player(state, id, "Joe")
    assert %Player{name: "Joe", id: ^id} = Things.get_player(state, id)
  end

  test "get_player/1 returns nil if the player is not found" do
    state = Things.new("foo")
    id = UUID.uuid4()

    assert Things.get_player(state, id) == nil
  end
end
