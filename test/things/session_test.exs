defmodule MPG.Things.SessionTest do
  use ExUnit.Case, async: true

  alias MPG.Things.Player
  alias MPG.Things.Session
  alias MPG.Things.State

  @player_id UUID.uuid4()
  @server_id "things_test"

  setup do
    # start_supervised will call Session.child_spec with the given opts
    # https://hexdocs.pm/elixir/1.12/Supervisor.html#module-child_spec-1
    server_pid = start_supervised!({Session, [name: @server_id]})
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)
    %{server: server_pid}
  end

  test "can ping the server" do
    assert Session.ping(@server_id) == :pong
  end

  test "can retrieve the state" do
    assert %State{} = Session.get_state(@server_id)
  end

  test "add_player/3 adds a new player", %{server: server} do
    Session.add_player(@server_id, @player_id, "Joe")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "add_player/3 sets first player as the host", %{server: server} do
    Session.add_player(@server_id, @player_id, "Joe")
    Session.add_player(@server_id, UUID.uuid4(), "Jane")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", is_host: true}, %Player{name: "Jane", is_host: false}] =
             state.players
  end

  test "add_player/3 adds player with a different color (in sequence)", %{server: server} do
    Session.add_player(@server_id, @player_id, "Joe")
    Session.add_player(@server_id, UUID.uuid4(), "Jane")
    Session.add_player(@server_id, UUID.uuid4(), "Justin")
    state = :sys.get_state(server)

    assert [
             %Player{name: "Joe", color: "Gold"},
             %Player{name: "Jane", color: "DarkSlateBlue"},
             %Player{name: "Justin", color: "DeepPink"}
           ] = state.players
  end

  test "add_player/3 broadcasts the new state" do
    Session.add_player(@server_id, @player_id, "Joe")

    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "set_player_answer/3 sets a player's answer", %{server: server} do
    Session.add_player(@server_id, @player_id, "Joe")
    Session.set_player_answer(@server_id, @player_id, "42")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", id: @player_id, current_answer: "42"}] = state.players
  end

  test "set_player_answer/3 broadcasts the new state" do
    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Session.set_player_answer(@server_id, @player_id, "42")
    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", current_answer: "42"}] = state.players
  end

  test "new_question/2 resets the topic and all player answers", %{server: server} do
    Session.add_player(@server_id, @player_id, "Joe")
    Session.set_player_answer(@server_id, @player_id, "42")
    Session.reveal_player(@server_id, @player_id, "12345")
    Session.new_question(@server_id, "Things that are awesome")
    state = :sys.get_state(server)

    assert %State{
             topic: "Things that are awesome",
             players: [%Player{id: @player_id, name: "Joe", current_answer: nil, revealed: false}]
           } = state
  end

  test "new_question/2 broadcasts the new state" do
    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Session.new_question(@server_id, "Things that are awesome")
    assert_receive({:state_updated, state})

    assert %State{
             topic: "Things that are awesome",
             players: [%Player{name: "Joe", current_answer: nil}]
           } = state
  end

  test "reveal_player/3 reveals the player and awards a point to the guesser", ctx do
    Session.add_player(@server_id, @player_id, "Joe")
    player2_id = UUID.uuid4()
    Session.add_player(@server_id, player2_id, "Bill")
    player3_id = UUID.uuid4()
    Session.add_player(@server_id, player3_id, "Sue")

    assert %{players: [joe, bill, sue]} = :sys.get_state(ctx.server)
    # %{players: [joe, bill]} = :sys.get_state(ctx.server)
    assert %Player{name: "Joe", revealed: false, score: nil} = joe
    assert %Player{name: "Bill", revealed: false, score: nil} = bill
    assert %Player{name: "Sue", revealed: false, score: nil} = sue

    Session.reveal_player(@server_id, @player_id, player2_id)

    %{players: [joe, bill, sue]} = :sys.get_state(ctx.server)
    assert %Player{name: "Joe", revealed: true, score: nil} = joe
    assert %Player{name: "Bill", revealed: false, score: 1} = bill
    assert %Player{name: "Sue", revealed: false, score: nil} = sue
  end

  test "reveal_player/2 broadcasts the new state" do
    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Session.reveal_player(@server_id, @player_id, "12345")

    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", revealed: true}] = state.players
  end

  test "remove_player/2" do
    Session.add_player(@server_id, @player_id, "Host")
    joe_id = UUID.uuid4()
    Session.add_player(@server_id, joe_id, "Player")
    Session.remove_player(@server_id, joe_id)

    assert_receive({:state_updated, state})
    assert %State{players: [player]} = state
    assert %Player{name: "Host", is_host: true, id: @player_id} = player
  end
end
