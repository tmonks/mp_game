defmodule MPG.Quizzes.SessionTest do
  use ExUnit.Case, async: true

  alias MPG.Quizzes.Player
  alias MPG.Quizzes.State
  alias MPG.Quizzes.Session

  @player_id UUID.uuid4()

  setup do
    server = start_supervised!(Session)
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
    state = :sys.get_state(server)

    assert [%Player{name: "Joe", current_answer: nil}] = state.players
  end

  test "answer_question/3 sets a player's answer", %{server: server} do
    Session.add_player(server, @player_id, "Joe")
    state = :sys.get_state(server)
    player = Enum.at(state.players, 0)

    assert player.current_answer == nil

    Session.answer_question(server, @player_id, 1)
    state = :sys.get_state(server)
    player = Enum.at(state.players, 0)

    assert player.current_answer == 1
  end

  test "create_quiz/2 creates a new quiz", %{server: server} do
    Session.create_quiz(server, "MCU Movie trivia")
    state = :sys.get_state(server)

    assert state.title == "MCU Movie trivia"
    assert state.current_question == 0
    assert length(state.questions) == 10
  end
end
