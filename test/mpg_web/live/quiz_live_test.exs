defmodule MPGWeb.QuizLiveTest do
  use MPGWeb.ConnCase

  import Phoenix.LiveViewTest

  alias MPG.Quizzes.Session

  setup %{conn: conn} do
    conn = init_test_session(conn, %{})

    # populate a session_id on the conn
    session_id = UUID.uuid4()
    conn = put_session(conn, :session_id, session_id)

    # Restart the session to clear out any state
    Supervisor.terminate_child(MPG.Supervisor, MPG.Things.Game)
    Supervisor.restart_child(MPG.Supervisor, MPG.Things.Game)

    # subscribe to PubSub
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, "quiz_session")

    {:ok, conn: conn, session_id: session_id}
  end

  test "if the player with the session_id does not exist, prompts for name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/quiz")

    assert has_element?(view, "#join-form")
  end

  test "can join the game", %{conn: conn, session_id: session_id} do
    {:ok, view, _html} = live(conn, ~p"/quiz")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert_receive({:state_updated, _state})
    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{conn: conn, session_id: session_id} do
    Session.add_player(:quiz_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/quiz")

    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "host is prompted to enter a question right after joining", ctx do
    Session.add_player(:quiz_session, ctx.session_id, "Host")

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    assert has_element?(view, "#new-quiz-modal")
  end
end