defmodule MPGWeb.ThingsLiveTest do
  use MPGWeb.ConnCase
  import Phoenix.LiveViewTest

  alias MPG.Things.Session

  setup %{conn: conn} do
    conn = init_test_session(conn, %{})
    session_id = UUID.uuid4()
    conn = put_session(conn, :session_id, session_id)
    {:ok, conn: conn, session_id: session_id}
  end

  test "if the player with the session_id does not exist, prompts for name", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Join"
  end

  test "can join the game", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert has_element?(view, "#player-name", "Peter")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-name", "Peter")
    refute has_element?(view, "#join-form")
  end
end
