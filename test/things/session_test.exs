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

  test "can set a player answer", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    Session.set_player_answer(server, "Joe", "42")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", current_answer: "42"}] = state.players
  end

  test "can reset the topic and all player answers", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    Session.set_player_answer(server, "Joe", "42")
    Session.new_question(server, "Things that are awesome")
    state = :sys.get_state(server)

    assert %State{
             topic: "Things that are awesome",
             players: [%Player{name: "Joe", current_answer: nil}]
           } = state
  end
end
