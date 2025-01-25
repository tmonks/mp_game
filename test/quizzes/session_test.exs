defmodule MPG.Quizzes.SessionTest do
  use ExUnit.Case, async: true

  alias MPG.Quizzes.Player
  alias MPG.Quizzes.State
  alias MPG.Quizzes.Session

  import MPG.Fixtures.OpenAI

  @player_id UUID.uuid4()
  @server_id "quiz_test"

  setup do
    server_pid = start_supervised!({Session, [name: @server_id]})
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)
    bypass = Bypass.open(port: 4010)

    %{server: server_pid, bypass: bypass}
  end

  test "can ping the server" do
    assert Session.ping(@server_id) == :pong
  end

  test "can retrieve the state" do
    assert %State{} = Session.get_state(@server_id)
  end

  test "add_player/3 adds a new player" do
    Session.add_player(@server_id, @player_id, "Joe")

    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "answer_question/3 sets a player's answer" do
    Session.add_player(@server_id, @player_id, "Joe")

    assert_receive({:state_updated, state})
    player = Enum.at(state.players, 0)
    assert player.current_answer == nil

    Session.answer_question(@server_id, @player_id, 1)

    assert_receive({:state_updated, state})
    player = Enum.at(state.players, 0)
    assert player.current_answer == 1
  end

  test "create_quiz/2 sets the title and generates questions with a background task", ctx do
    Bypass.expect_once(ctx.bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.resp(conn, 200, chat_response_quiz_questions())
    end)

    Session.create_quiz(@server_id, "MCU Movie trivia")

    # title is set
    assert_receive({:state_updated, state})
    assert state.title == "MCU Movie trivia"
    assert state.current_question == nil
    assert state.questions == []

    # questions are generated
    assert_receive({:state_updated, state})
    assert length(state.questions) == 10

    assert Enum.at(state.questions, 0).text == "What is the first movie in the MCU?"
  end

  test "set_questions/2 sets the questions for the quiz" do
    questions = [
      %{
        text: "What is 1 + 1",
        answers: ["3", "7", "2", "5"],
        correct_answer: 2,
        explanation: "1 + 1 = 2"
      }
    ]

    Session.set_questions(@server_id, questions)

    assert_receive({:state_updated, state})
    assert [%{text: "What is 1 + 1"}] = state.questions
  end

  test "next_question/2 progresses state to the next question", ctx do
    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    expect_api_call_to_generate_questions(ctx.bypass)

    # create the quiz and receive the updated state (title set and questions generated)
    Session.create_quiz(@server_id, "MCU Movie trivia")
    assert_receive({:state_updated, _state})
    assert_receive({:state_updated, state})

    assert state.current_question == nil

    # start the quiz
    Session.next_question(@server_id)
    assert_receive({:state_updated, _state})

    Session.next_question(@server_id)

    assert_receive({:state_updated, state})
    assert state.current_question == 1
  end

  test "next_question/2 updates players' scores", ctx do
    expect_api_call_to_generate_questions(ctx.bypass)
    # create the quiz and receive the updated state (title set and questions generated)
    Session.create_quiz(@server_id, "MCU Movie trivia")
    assert_receive({:state_updated, _state})
    assert_receive({:state_updated, _state})

    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, state})

    assert Enum.at(state.players, 0).score == 0

    # start the quiz
    Session.next_question(@server_id)
    assert_receive({:state_updated, _state})

    # correct answer to the first question is 0
    Session.answer_question(@server_id, @player_id, 0)
    assert_receive({:state_updated, _state})
    Session.next_question(@server_id)
    assert_receive({:state_updated, state})

    assert Enum.at(state.players, 0).score == 1
  end

  defp expect_api_call_to_generate_questions(bypass) do
    Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.resp(conn, 200, chat_response_quiz_questions())
    end)
  end
end
