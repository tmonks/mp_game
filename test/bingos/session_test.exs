defmodule MPG.Bingos.SessionTest do
  use ExUnit.Case, async: true

  alias MPG.Bingos.Player
  alias MPG.Bingos.Session
  alias MPG.Bingos.State

  @player_id UUID.uuid4()
  @server_id "bingos_test"

  setup do
    server_pid = start_supervised!({Session, [name: @server_id]})
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)
    %{server: server_pid}
  end

  test "can ping the server" do
    assert Session.ping(@server_id) == :pong
  end

  test "get_state/1 retrieves the state" do
    assert {:ok, %State{}} = Session.get_state(@server_id)
  end

  test "get_state/1 returns an error tuple if server doesn't exist" do
    assert {:error, :not_found} = Session.get_state("non_existent_server")
  end

  test "init/1 creates a new state with no players and 25 cells" do
    assert {:ok, %State{players: [], cells: cells}} = Session.get_state(@server_id)
    assert length(cells) == 25
  end

  test "add_player/3 adds a new player", %{server: server} do
    Session.add_player(@server_id, @player_id, "Joe")
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", id: @player_id}] = state.players
  end

  test "add_player/3 broadcasts the new state" do
    Session.add_player(@server_id, @player_id, "Joe")

    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", id: @player_id}] = state.players
  end

  test "toggle_cell/3 toggles a cell for a player", %{server: server} do
    Session.add_player(@server_id, @player_id, "Joe")
    Session.toggle_cell(@server_id, 5, @player_id)
    state = :sys.get_state(server)

    assert Enum.at(state.cells, 5).player_id == @player_id
  end

  test "toggle_cell/3 broadcasts the new state" do
    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Session.toggle_cell(@server_id, 5, @player_id)
    assert_receive({:state_updated, state})
    assert Enum.at(state.cells, 5).player_id == @player_id
  end
end
