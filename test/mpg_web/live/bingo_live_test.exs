defmodule MPGWeb.BingoLiveTest do
  use MPGWeb.ConnCase

  import Phoenix.LiveViewTest
  alias MPG.Bingos.Session
  alias MPG.Bingos.State

  setup do
    server_id = "test_server"
    start_supervised!({Session, [name: server_id]})

    # populate a session_id on the conn
    session_id = UUID.uuid4()
    conn = init_test_session(build_conn(), %{session_id: session_id})

    # subscribe to PubSub
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, server_id)

    %{conn: conn, server_id: server_id, session_id: session_id}
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
    conn: conn,
    server_id: server_id
  } do
    {:ok, view, _html} = live(conn, ~p"/bingo/#{server_id}")

    assert has_element?(view, "#join-form")
  end

  test "can join the game", %{conn: conn, server_id: server_id, session_id: session_id} do
    {:ok, view, _html} = live(conn, ~p"/bingo/#{server_id}")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert_receive {:state_updated, %State{}}
    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{
    conn: conn,
    server_id: server_id,
    session_id: session_id
  } do
    Session.add_player(server_id, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/bingo/#{server_id}")

    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end
end
