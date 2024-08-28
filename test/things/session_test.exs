defmodule MPG.Things.SessionTest do
  use ExUnit.Case, async: true

  alias MPG.Things.Player
  alias MPG.Things.Session
  alias MPG.Things.State

  @player_id UUID.uuid4()

  setup do
    server = start_supervised!(Session)
    %{server: server}
  end

  test "can ping the server", %{server: server} do
    assert Session.ping(server) == :pong
  end

  test "can retrieve the state", %{server: server} do
    assert %State{} = Session.get_state(server)
  end

  test "can add a player", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "set_player_answer/3 can set a player answer", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    Session.set_player_answer(server, @player_id, "42")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", id: @player_id, current_answer: "42"}] = state.players
  end

  test "can reset the topic and all player answers", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    Session.set_player_answer(server, @player_id, "42")
    Session.new_question(server, "Things that are awesome")
    state = :sys.get_state(server)

    assert %State{
             topic: "Things that are awesome",
             players: [%Player{id: @player_id, name: "Joe", current_answer: nil}]
           } = state
  end

  test "can reveal a player's answer", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    assert %{players: [%Player{name: "Joe", revealed: nil}]} = :sys.get_state(server)

    Session.set_player_to_revealed(server, @player_id)
    assert %{players: [%Player{name: "Joe", revealed: true}]} = :sys.get_state(server)
  end

  test "all_players_answered?/1 returns true if all players have an answer", %{server: server} do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()

    Session.add_player(server, joe_id, "Joe")
    refute Session.all_players_answered?(server)

    Session.set_player_answer(server, joe_id, "42")
    assert Session.all_players_answered?(server)

    Session.add_player(server, jane_id, "Jane")
    refute Session.all_players_answered?(server)

    Session.set_player_answer(server, jane_id, "43")
    assert Session.all_players_answered?(server)
  end
end
