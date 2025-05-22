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

  @tag :skip
  test "visiting /bingo redirects to a random server ID and generates cells", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path}}} = live(conn, ~p"/bingo")

    assert new_path =~ ~r"/bingo/[0-9]{5}"

    # retrieve the server name from the `name` URL param
    server_id = new_path |> String.split("/") |> List.last()

    # Session GenServer started with that name
    assert {:ok, %State{server_id: ^server_id}} = Session.get_state(server_id)

    # wait for the cells to be generated
    assert_receive {:state_updated, %State{cells: cells}}
    assert length(cells) == 25
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

  test "can join the game", %{conn: conn, session_id: session_id} do
    {:ok, view, _html} = live(conn, ~p"/bingo/#{@server_id}")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert_receive {:state_updated, %State{}}
    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
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

  test "calls Generator to generate the bingo grid", %{conn: conn, bypass: bypass} do
    # Visit /bingo and follow the redirect
    {:error, {:live_redirect, %{to: new_path}}} = live(conn, ~p"/bingo")
    server_id = new_path |> String.split("/") |> List.last()

    Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.resp(conn, 200, chat_response_bingo_cells())
    end)

    # Visit the new server ID and join the game
    {:ok, view, _html} = live(conn, ~p"/bingo/#{server_id}")

    # wait for the cells to be generated
    assert_receive {:state_updated, %State{cells: cells}}
    assert length(cells) == 25

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    # Wait for state update and verify cells are populated
    assert_receive {:state_updated, %State{}}
    refute has_element?(view, ".loader")
    assert has_element?(view, "#cell-0")
    assert has_element?(view, "#cell-24")
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
