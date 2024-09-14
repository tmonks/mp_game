defmodule MPG.Things.GameTest do
  use ExUnit.Case, async: true

  alias MPG.Things.Player
  alias MPG.Things.Game
  alias MPG.Things.State

  @player_id UUID.uuid4()

  setup do
    server = start_supervised!(Game)
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, "things_session")
    %{server: server}
  end

  test "can ping the server", %{server: server} do
    assert Game.ping(server) == :pong
  end

  test "can retrieve the state", %{server: server} do
    assert %State{} = Game.get_state(server)
  end

  test "add_player/3 adds a new player", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "add_player/3 sets first player as the host", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    Game.add_player(server, UUID.uuid4(), "Jane")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", is_host: true}, %Player{name: "Jane", is_host: false}] =
             state.players
  end

  test "add_player/3 broadcasts the new state", %{server: server} do
    Game.add_player(server, @player_id, "Joe")

    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "set_player_answer/3 sets a player's answer", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    Game.set_player_answer(server, @player_id, "42")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", id: @player_id, current_answer: "42"}] = state.players
  end

  test "set_player_answer/3 broadcasts the new state", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Game.set_player_answer(server, @player_id, "42")
    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", current_answer: "42"}] = state.players
  end

  test "new_question/2 resets the topic and all player answers", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    Game.set_player_answer(server, @player_id, "42")
    Game.set_player_to_revealed(server, @player_id)
    Game.new_question(server, "Things that are awesome")
    state = :sys.get_state(server)

    assert %State{
             topic: "Things that are awesome",
             players: [%Player{id: @player_id, name: "Joe", current_answer: nil, revealed: false}]
           } = state
  end

  test "new_question/2 broadcasts the new state", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Game.new_question(server, "Things that are awesome")
    assert_receive({:state_updated, state})

    assert %State{
             topic: "Things that are awesome",
             players: [%Player{name: "Joe", current_answer: nil}]
           } = state
  end

  test "set_player_to_revealed/2 sets a player to revealed", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    assert %{players: [%Player{name: "Joe", revealed: false}]} = :sys.get_state(server)

    Game.set_player_to_revealed(server, @player_id)
    assert %{players: [%Player{name: "Joe", revealed: true}]} = :sys.get_state(server)
  end

  test "set_player_to_revealed/2 broadcasts the new state", %{server: server} do
    Game.add_player(server, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Game.set_player_to_revealed(server, @player_id)

    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", revealed: true}] = state.players
  end

  test "all_players_answered?/1 returns true if all players have an answer", %{server: server} do
    joe_id = UUID.uuid4()
    jane_id = UUID.uuid4()

    Game.add_player(server, joe_id, "Joe")
    refute Game.all_players_answered?(server)

    Game.set_player_answer(server, joe_id, "42")
    assert Game.all_players_answered?(server)

    Game.add_player(server, jane_id, "Jane")
    refute Game.all_players_answered?(server)

    Game.set_player_answer(server, jane_id, "43")
    assert Game.all_players_answered?(server)
  end
end
