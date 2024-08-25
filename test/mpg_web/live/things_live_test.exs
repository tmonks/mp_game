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

  test "can join the game", %{conn: conn, session_id: session_id} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert has_element?(view, "#player-#{session_id} [data-role=player-name]", "Me")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{session_id} [data-role=player-name]", "Me")
    refute has_element?(view, "#join-form")
  end

  test "lists current player as 'Me'", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{session_id} [data-role=player-name]", "Me")
  end

  test "shows current answer for current player", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")
    Session.set_player_answer(:things_session, "Peter", "bananas")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{session_id} [data-role=answer]", "bananas")
  end

  test "shows 'No answer yet' for other players that have not provided an answer", %{conn: conn} do
    id = UUID.uuid4()
    Session.add_player(:things_session, id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{id}", "Peter")
    assert has_element?(view, "#player-#{id} [data-role=answer]", "No answer yet")
  end

  test "shows 'Ready' for other players that have provided an answer", %{conn: conn} do
    id = UUID.uuid4()
    Session.add_player(:things_session, id, "Peter")
    Session.set_player_answer(:things_session, "Peter", "bananas")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{id}", "Peter")
    assert has_element?(view, "#player-#{id} [data-role=answer]", "Ready")
  end

  test "shows the current question", %{conn: conn} do
    Session.new_question(:things_session, "Things that are red")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#current-question", "Things that are red")
  end

  test "player can submit answer", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#answer-form", %{answer: "bananas"})
    |> render_submit()

    assert has_element?(view, "#player-#{session_id} [data-role=answer]", "bananas")
  end
end
