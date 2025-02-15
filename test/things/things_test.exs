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
    assert jane == %Player{name: "Jane", current_answer: nil, revealed: false}
    assert joe == %Player{name: "Joe", current_answer: nil, revealed: false}
  end

  test "add_player/3 adds a player to the state" do
    state = Things.new("foo")
    id = UUID.uuid4()

    assert %State{topic: "foo", players: [player]} = Things.add_player(state, id, "Joe")
    assert player.name == "Joe"
    assert player.id == id
    assert player.current_answer == nil
    assert player.revealed == false
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

  test "get_player/2 retrieves the player with the given id" do
    state = Things.new("foo")
    id = UUID.uuid4()

    state = Things.add_player(state, id, "Joe")
    assert %Player{name: "Joe", id: ^id} = Things.get_player(state, id)
  end

  test "get_player/2 returns nil if the player is not found" do
    state = Things.new("foo")
    id = UUID.uuid4()

    assert Things.get_player(state, id) == nil
  end

  test "all_players_answered?/1 returns true if all players have answered" do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.add_player(jane_id, "Jane")

    state = Things.set_player_answer(state, joe_id, "banana")
    refute Things.all_players_answered?(state)

    state = Things.set_player_answer(state, jane_id, "apple")
    assert Things.all_players_answered?(state)
  end

  test "current_status/1 returns :new if a question has not yet been set" do
    state = %State{topic: nil}
    assert Things.current_status(state) == :new
  end

  test "current_status/1 returns :answering if a question has been set but not all players have answered" do
    joe_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")

    refute Things.all_players_answered?(state)
    assert Things.current_status(state) == :answering
  end

  test "current_status/1 returns :guessing if all players have answered the question" do
    joe_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.set_player_answer(joe_id, "banana")

    assert Things.all_players_answered?(state)
    assert Things.current_status(state) == :guessing
  end

  test "current_status/1 returns :complete if all player answers have been revealed" do
    joe_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.set_player_answer(joe_id, "banana")
      |> Things.reveal_player(joe_id, "12345")

    assert Things.current_status(state) == :complete
  end

  test "remove_player/2 removes the player with the given id" do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.add_player(jane_id, "Jane")

    assert %State{players: players} = Things.remove_player(state, joe_id)
    assert length(players) == 1
    assert Enum.find(players, &(&1.id == joe_id)) == nil
  end

  test "reveal_player/3 reveals the last player automatically" do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()
    bill_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.add_player(jane_id, "Jane")
      |> Things.add_player(bill_id, "Bill")
      |> Things.set_player_answer(joe_id, "banana")
      |> Things.set_player_answer(jane_id, "apple")
      |> Things.set_player_answer(bill_id, "orange")

    state = Things.reveal_player(state, joe_id, "12345")

    assert [
             %{name: "Joe", revealed: true},
             %{name: "Jane", revealed: false},
             %{name: "Bill", revealed: false}
           ] = state.players

    state = Things.reveal_player(state, jane_id, "12345")

    assert [
             %{name: "Joe", revealed: true},
             %{name: "Jane", revealed: true},
             # bill marked as revealed automatically
             %{name: "Bill", revealed: true}
           ] = state.players
  end

  test "reveal_player/3 awards a point to the guesser" do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()
    bill_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.add_player(jane_id, "Jane")
      |> Things.add_player(bill_id, "Bill")
      |> Things.set_player_answer(joe_id, "banana")
      |> Things.set_player_answer(jane_id, "apple")
      |> Things.set_player_answer(bill_id, "orange")

    state = Things.reveal_player(state, joe_id, jane_id)

    assert [
             %{name: "Joe", revealed: true, score: nil},
             %{name: "Jane", revealed: false, score: 1},
             %{name: "Bill", revealed: false, score: nil}
           ] = state.players
  end

  test "reveal_player/3 does not award a point if the guesser is one of the last 2 players" do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()
    bill_id = UUID.uuid4()

    state =
      Things.new("foo")
      |> Things.add_player(joe_id, "Joe")
      |> Things.add_player(jane_id, "Jane")
      |> Things.add_player(bill_id, "Bill")
      |> Things.set_player_answer(joe_id, "banana")
      |> Things.set_player_answer(jane_id, "apple")
      |> Things.set_player_answer(bill_id, "orange")

    state = Things.reveal_player(state, joe_id, jane_id)

    assert [
             # Joe is revealed
             %{name: "Joe", revealed: true, score: nil},
             # Jane gets a point
             %{name: "Jane", revealed: false, score: 1},
             %{name: "Bill", revealed: false, score: nil}
           ] = state.players

    state = Things.reveal_player(state, bill_id, jane_id)

    assert [
             %{name: "Joe", revealed: true, score: nil},
             # Jane is revealed
             %{name: "Jane", revealed: true, score: 1},
             # Bill gets auto-revealed, but does NOT get a point
             %{name: "Bill", revealed: true, score: nil}
           ] = state.players
  end
end
