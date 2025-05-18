defmodule MPG.Bingos.SessionTest do
  use ExUnit.Case, async: false

  import MPG.Fixtures.OpenAI

  alias MPG.Bingos.Player
  alias MPG.Bingos.Session
  alias MPG.Bingos.State

  @player_id UUID.uuid4()
  @server_id "bingos_test"

  setup do
    server_pid = start_supervised!({Session, [name: @server_id]})
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)
    bypass = Bypass.open(port: 4010)

    %{server: server_pid, bypass: bypass}
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

  test "init/1 creates a new state with no players and no cells" do
    assert {:ok, %State{players: [], cells: []}} = Session.get_state(@server_id)
  end

  test "update_cells/2 updates the cells in the state", %{server: server} do
    Session.update_cells(@server_id, make_cells())
    state = :sys.get_state(server)

    assert length(state.cells) == 25
  end

  test "update_cells/2 broadcasts the new state" do
    Session.update_cells(@server_id, make_cells())
    assert_receive({:state_updated, state})
    assert length(state.cells) == 25
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
    Session.update_cells(@server_id, make_cells())
    Session.toggle_cell(@server_id, 5, @player_id)
    state = :sys.get_state(server)

    assert Enum.at(state.cells, 5).player_id == @player_id
  end

  test "toggle_cell/3 broadcasts the new state" do
    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Session.update_cells(@server_id, make_cells())
    assert_receive({:state_updated, _state})

    Session.toggle_cell(@server_id, 5, @player_id)
    assert_receive({:state_updated, state})
    assert Enum.at(state.cells, 5).player_id == @player_id
  end

  test "generate/1 generates new cells and broadcasts the updated state", ctx do
    Bypass.expect_once(ctx.bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.resp(conn, 200, chat_response_bingo_cells())
    end)

    Session.generate(@server_id, "test")
    assert_receive({:state_updated, state})
    assert length(state.cells) == 25
    assert Enum.all?(state.cells, &(&1.text != nil))
  end

  defp make_cells do
    Enum.map(1..25, &"Cell #{&1}")
  end
end
