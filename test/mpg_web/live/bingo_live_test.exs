defmodule MPGWeb.BingoLiveTest do
  use MPGWeb.ConnCase, async: false

  import MPG.Fixtures.OpenAI
  import Phoenix.LiveViewTest
  alias MPG.Bingos.Session
  alias MPG.Bingos.State

  @server_id "bingo_session"
  setup %{conn: conn} do
    conn = init_test_session(conn, %{})

    # populate a session_id on the conn
    session_id = UUID.uuid4()
    conn = put_session(conn, :session_id, session_id)

    start_supervised!({Session, [name: @server_id]})

    # subscribe to PubSub
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)

    # Set up Bypass expectation for the API calls to generate cells
    bypass = Bypass.open(port: 4010)

    %{conn: conn, session_id: session_id, bypass: bypass}
  end

  test "visiting /bingo redirects to a random server ID", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path}}} = live(conn, ~p"/bingo")

    assert new_path =~ ~r"/bingo/[0-9]{5}"

    # retrieve the server name from the `name` URL param
    server_id = new_path |> String.split("/") |> List.last()

    # Session GenServer started with that name
    assert {:ok, %State{server_id: ^server_id}} = Session.get_state(server_id)
  end

  test "redirects to home page if the server ID is invalid", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path, flash: flash}}} =
      live(conn, ~p"/bingo/invalidid")

    assert new_path == "/"
    assert flash["error"] == "Game not found"
  end

  test "if the player with the session_id does not exist, prompts for name", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/bingo/#{@server_id}")

    assert has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{
    conn: conn,
    session_id: session_id
  } do
    Session.add_player(@server_id, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/bingo/#{@server_id}")

    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "shows a loading animation while the cells are being generated", %{
    conn: conn,
    session_id: session_id
  } do
    Session.add_player(@server_id, session_id, "Peter")
    {:ok, view, _html} = live(conn, ~p"/bingo/#{@server_id}")

    assert has_element?(view, ".loader")
  end

  test "host is prompted to select a bingo type right after joining", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/bingo/#{@server_id}")

    view
    |> form("#join-form", %{player_name: "Host"})
    |> render_submit()

    assert_receive({:state_updated, _state})
    assert_patch(view, ~p"/bingo/#{@server_id}/new")
    assert has_element?(view, "#bingo-type-form")

    Bypass.expect_once(ctx.bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.resp(conn, 200, chat_response_bingo_cells())
    end)

    view
    |> form("#bingo-type-form", %{type: "conversation"})
    |> render_submit()

    assert_patch(view, ~p"/bingo/#{@server_id}")
    refute has_element?(view, "#bingo-type-form")

    assert_receive({:state_updated, _state})
    # TODO: why are we receiving two state_updated events?
    assert_receive({:state_updated, state})
    assert state.cells |> length() == 25
    assert has_element?(view, "#cell-0")
    assert has_element?(view, "#cell-24")
  end

  test "non-host players can join and see their avatar", %{conn: conn, session_id: session_id} do
    uuid = UUID.uuid4()
    Session.add_player(@server_id, uuid, "Host")

    {:ok, view, _html} = live(conn, ~p"/bingo/#{@server_id}")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert_receive {:state_updated, %State{} = state}
    assert length(state.players) == 1
    assert_receive {:state_updated, %State{} = state}
    assert length(state.players) == 2
    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "can toggle a cell", %{conn: conn, session_id: session_id} do
    Session.add_player(@server_id, session_id, "Peter")

    # populate the cells
    cells = for i <- 0..24, do: "cell-#{i}"
    Session.update_cells(@server_id, cells)

    {:ok, view, _html} = live(conn, ~p"/bingo/#{@server_id}")

    # Click a cell
    view
    |> element("#cell-0")
    |> render_click()

    assert_receive {:state_updated, %State{}}

    # Cell should be green and show player marker
    assert has_element?(view, "#cell-0.bg-green-500")
    assert has_element?(view, "#cell-0 div[style*='#{get_player_color(session_id)}']")
  end

  defp get_player_color(session_id) do
    {:ok, state} = Session.get_state(@server_id)
    player = Enum.find(state.players, &(&1.id == session_id))
    player.color
  end
end
