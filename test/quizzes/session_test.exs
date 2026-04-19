defmodule MPG.Quizzes.SessionTest do
  use ExUnit.Case, async: false

  alias MPG.Quizzes.Player
  alias MPG.Quizzes.State
  alias MPG.Quizzes.Session

  import Mox
  import MPG.Fixtures.OpenAI

  @player_id UUID.uuid4()
  @server_id "quiz_test"

  setup do
    set_mox_global()
    server_pid = start_supervised!({Session, [name: @server_id]})
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)

    %{server: server_pid}
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

  test "add_player/3 adds a new player" do
    Session.add_player(@server_id, @player_id, "Joe")

    assert_receive({:state_updated, _action, state})
    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "answer_question/3 sets a player's answer" do
    Session.add_player(@server_id, @player_id, "Joe")

    assert_receive({:state_updated, _action, state})
    player = Enum.at(state.players, 0)
    assert player.current_answer == nil

    Session.answer_question(@server_id, @player_id, 1)

    assert_receive({:state_updated, _action, state})
    player = Enum.at(state.players, 0)
    assert player.current_answer == 1
  end

  test "create_quiz/2 sets the title and generates questions with a background task" do
    mock_quiz_questions()

    Session.create_quiz(@server_id, "MCU Movie trivia")

    # title is set
    assert_receive({:state_updated, _action, state})
    assert state.title == "MCU Movie trivia"
    assert state.current_question == nil
    assert state.questions == []

    # questions are generated
    assert_receive({:state_updated, _action, state})
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

    assert_receive({:state_updated, _action, state})
    assert [%{text: "What is 1 + 1"}] = state.questions
  end

  test "next_question/2 progresses state to the next question" do
    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _action, _state})

    mock_quiz_questions()

    # create the quiz and receive the updated state (title set and questions generated)
    Session.create_quiz(@server_id, "MCU Movie trivia")
    assert_receive({:state_updated, _action, _state})
    assert_receive({:state_updated, _action, state})

    assert state.current_question == nil

    # start the quiz
    Session.next_question(@server_id)
    assert_receive({:state_updated, _action, _state})

    Session.next_question(@server_id)

    assert_receive({:state_updated, _action, state})
    assert state.current_question == 1
  end

  test "next_question/2 updates players' scores" do
    mock_quiz_questions()

    # create the quiz and receive the updated state (title set and questions generated)
    Session.create_quiz(@server_id, "MCU Movie trivia")
    assert_receive({:state_updated, _action, _state})
    assert_receive({:state_updated, _action, _state})

    Session.add_player(@server_id, @player_id, "Joe")
    assert_receive({:state_updated, _action, state})

    assert Enum.at(state.players, 0).score == 0

    # start the quiz
    Session.next_question(@server_id)
    assert_receive({:state_updated, _action, _state})

    # correct answer to the first question is 0
    Session.answer_question(@server_id, @player_id, 0)
    assert_receive({:state_updated, _action, _state})
    Session.next_question(@server_id)
    assert_receive({:state_updated, _action, state})

    assert Enum.at(state.players, 0).score == 1
  end
end
