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
    Supervisor.terminate_child(MPG.Supervisor, MPG.Quizzes.Session)
    Supervisor.restart_child(MPG.Supervisor, MPG.Quizzes.Session)

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

    view
    |> form("#new-quiz-form", %{title: "Marvel characters"})
    |> render_submit()

    assert_receive({:state_updated, _state})
    Process.sleep(100)

    refute has_element?(view, "#new-quiz-modal")
  end

  test "players see the quiz title and status", ctx do
    Session.add_player(:quiz_session, ctx.session_id, "Host")

    # player joined
    assert_receive({:state_updated, _state})

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    assert has_element?(view, "#current-status", "Waiting for the host to set the quiz topic")

    view
    |> form("#new-quiz-form", %{title: "Marvel characters"})
    |> render_submit()

    # title set
    assert_receive({:state_updated, state})
    assert state.title == "Marvel characters"

    # TODO: figure out how to test this
    # assert has_element?(view, "#current-status", "Generating quiz")

    # questions generated
    assert_receive({:state_updated, state})
    assert length(state.questions) == 10
    assert has_element?(view, "#current-status", "Waiting for players to join")
  end

  test "host can click a 'Start Quiz' button to start the quiz after it's generated", ctx do
    Session.add_player(:quiz_session, ctx.session_id, "Host")
    assert_receive({:state_updated, _state})

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> form("#new-quiz-form", %{title: "Marvel characters"})
    |> render_submit()

    # title set
    assert_receive({:state_updated, state})
    assert state.title == "Marvel characters"

    # questions generated
    assert_receive({:state_updated, state})
    assert length(state.questions) == 10

    view
    |> element("#next-button")
    |> render_click()

    assert_receive({:state_updated, state})
    assert state.current_question == 0
  end

  test "players can answer questions and show they're ready", ctx do
    start_quiz(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}] = state.players

    assert has_element?(view, "#player-#{ctx.session_id} [data-role=ready-check-mark]")
  end

  test "after all players have answered, the correct answer is revealed", ctx do
    start_quiz(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}] = state.players

    assert has_element?(view, "#answer-0[data-role=correct]")
    assert has_element?(view, "#answer-1[data-role=incorrect]")
    assert has_element?(view, "#answer-2[data-role=incorrect]")
    assert has_element?(view, "#answer-2[data-role=incorrect]")
  end

  defp start_quiz(player_id) do
    # join player
    Session.add_player(:quiz_session, player_id, "Host")
    assert_receive({:state_updated, _state})

    # set title and questions
    Session.create_quiz(:quiz_session, "Marvel characters")
    assert_receive({:state_updated, _state})
    assert_receive({:state_updated, _state})

    # start quiz
    Session.start_quiz(:quiz_session)
    assert_receive({:state_updated, _state})
  end
end
