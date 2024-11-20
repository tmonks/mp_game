defmodule MPG.Quizzes.SessionTest do
  use ExUnit.Case, async: true

  alias MPG.Quizzes.Player
  alias MPG.Quizzes.State
  alias MPG.Quizzes.Session

  @player_id UUID.uuid4()

  setup do
    server = start_supervised!(Session)
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, "quiz_session")
    %{server: server}
  end

  test "can ping the server", %{server: server} do
    assert Session.ping(server) == :pong
  end

  test "can retrieve the state", %{server: server} do
    assert %State{} = Session.get_state(server)
  end

  test "add_player/3 adds a new player", %{server: server} do
    Session.add_player(server, @player_id, "Joe")

    assert_receive({:state_updated, state})
    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "answer_question/3 sets a player's answer", %{server: server} do
    Session.add_player(server, @player_id, "Joe")

    assert_receive({:state_updated, state})
    player = Enum.at(state.players, 0)
    assert player.current_answer == nil

    Session.answer_question(server, @player_id, 1)

    assert_receive({:state_updated, state})
    player = Enum.at(state.players, 0)
    assert player.current_answer == 1
  end

  test "create_quiz/2 sets the title and generates questions", %{server: server} do
    Session.create_quiz(server, "MCU Movie trivia")

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

  test "generate_questions/1 generates questions and adds them to the quiz", %{server: server} do
    Session.generate_questions(server, "MCU Movie trivia")

    assert_receive({:state_updated, state})

    assert length(state.questions) == 10
    assert Enum.at(state.questions, 0).text == "What is the first movie in the MCU?"
  end

  test "next_question/2 progresses state to the next question", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    assert_receive({:state_updated, _state})

    Session.create_quiz(server, "MCU Movie trivia")

    # title set
    assert_receive({:state_updated, _state})
    # questions generated
    assert_receive({:state_updated, state})

    assert state.current_question == nil

    Session.next_question(server)

    assert_receive({:state_updated, state})
    assert state.current_question == 0
  end

  test "next_question/2 updates players' scores", %{server: server} do
    Session.create_quiz(server, "MCU Movie trivia")
    assert_receive({:state_updated, _state})
    Session.add_player(server, @player_id, "Joe")
    assert_receive({:state_updated, state})

    assert Enum.at(state.players, 0).score == 0

    # correct answer to the first question is 0
    Session.answer_question(server, @player_id, 0)
    assert_receive({:state_updated, _state})
    Session.next_question(server)
    assert_receive({:state_updated, state})

    assert Enum.at(state.players, 0).score == 1
  end
end
