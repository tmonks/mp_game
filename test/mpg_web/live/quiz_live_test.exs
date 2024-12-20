defmodule MPGWeb.QuizLiveTest do
  use MPGWeb.ConnCase

  import Phoenix.LiveViewTest
  import MPG.Fixtures.OpenAI

  alias MPG.Quizzes.Player
  alias MPG.Quizzes.Question
  alias MPG.Quizzes.Session
  alias MPG.Quizzes.State

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

    # set up bypass with stub for OpenAI API call
    bypass = Bypass.open(port: 4010)

    Bypass.stub(bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.resp(conn, 200, chat_response_quiz_questions())
    end)

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
    add_player("Player 2")

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}, _player2] = state.players

    assert has_element?(view, "#player-#{ctx.session_id} [data-role=ready-check-mark]")
  end

  test "reveals the correct answer after player answers", ctx do
    start_quiz(ctx.session_id)
    add_player("Player 2")

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}, _player2] = state.players

    assert has_element?(view, "#answer-0[data-role=correct]")
  end

  test "shows if the user's answer was incorrect", ctx do
    start_quiz(ctx.session_id)
    add_player("Player 2")

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> element("#answer-1")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 1}, _player2] = state.players

    assert has_element?(view, "#answer-1[data-role=incorrect]")
    # other answers are NOT marked incorrect
    assert has_element?(view, "#answer-0[data-role=correct]")
    assert has_element?(view, "#answer-2[data-role=not_selected]")
    assert has_element?(view, "#answer-3[data-role=not_selected]")
  end

  test "shows 'Correct' with the explanation if the player's answer was correct", ctx do
    start_quiz(ctx.session_id)
    add_player("Player 2")

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    refute has_element?(view, "#explanation")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}, _player2] = state.players

    assert has_element?(view, "#explanation", "Correct! Iron Man (2008)")
  end

  test "shows 'Incorrect' with the explanation if the player's answer was correct", ctx do
    start_quiz(ctx.session_id)
    add_player("Player 2")

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    refute has_element?(view, "#explanation")

    view
    |> element("#answer-1")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 1}, _player2] = state.players

    assert has_element?(view, "#explanation", "Incorrect. Iron Man (2008)")
  end

  test "after player answers, they can see player markers next to the answers", ctx do
    start_quiz(ctx.session_id)
    add_player("Player 2")

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}, _player2] = state.players

    assert has_element?(view, "#answer-0 #player-marker-#{ctx.session_id}")
  end

  test "after all players have answered, the host gets a button to move to the next question",
       ctx do
    start_quiz(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}] = state.players

    assert has_element?(view, "#next-button")

    view
    |> element("#next-button")
    |> render_click()

    assert_receive({:state_updated, state})
    assert state.current_question == 1
  end

  test "shows a counter with the current question number", ctx do
    start_quiz(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    assert has_element?(view, "#question-counter", "1 of 10")

    view
    |> element("#answer-0")
    |> render_click()

    assert_receive({:state_updated, state})
    assert [%{current_answer: 0}] = state.players

    view
    |> element("#next-button")
    |> render_click()

    assert_receive({:state_updated, _state})
    assert has_element?(view, "#question-counter", "2 of 10")
  end

  test "shows each player's score when the quiz is complete", ctx do
    player2_id = UUID.uuid4()

    state = %State{
      title: "Marvel characters",
      questions: [
        %Question{correct_answer: 0},
        %Question{correct_answer: 1},
        %Question{correct_answer: 2}
      ],
      current_question: 3,
      players: [
        %Player{id: ctx.session_id, name: "Host", score: 1, color: "Teal", is_host: true},
        %Player{id: player2_id, name: "Player 2", score: 2, color: "Gold"}
      ]
    }

    Session.set_state(:quiz_session, state)

    {:ok, view, _html} = live(ctx.conn, ~p"/quiz")

    open_browser(view)

    assert has_element?(view, "#score-#{ctx.session_id}", "33%")
    assert has_element?(view, "#score-#{player2_id}", "67%")
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
    Session.next_question(:quiz_session)
    assert_receive({:state_updated, _state})
  end

  defp add_player(name) do
    id = UUID.uuid4()
    Session.add_player(:quiz_session, id, name)
    assert_receive({:state_updated, _state})
    id
  end
end
