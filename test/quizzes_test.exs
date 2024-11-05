defmodule MPG.QuizzesTest do
  use ExUnit.Case

  alias MPG.Quizzes
  alias MPG.Quizzes.Player
  alias MPG.Quizzes.Question
  alias MPG.Quizzes.State

  describe "create_quiz/1" do
    test "creates a new state with valid attributes" do
      attrs = %{
        title: "Marvel characters",
        questions: [
          %{
            text: "Who is the strongest Avenger?",
            answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
            correct_answer: 0,
            explanation: "Hulk is the strongest Avenger."
          }
        ]
      }

      assert {:ok, %State{} = state} = Quizzes.create_quiz(attrs)

      assert state.title == "Marvel characters"
      assert state.current_question == 0
      assert [%Question{} = question] = state.questions
      assert question.text == "Who is the strongest Avenger?"
      assert question.answers == ["Hulk", "Thor", "Iron Man", "Captain America"]
      assert question.correct_answer == 0
      assert question.explanation == "Hulk is the strongest Avenger."
    end
  end

  describe "add_player/3" do
    test "adds a player to the state" do
      state = state_fixture()
      player_id = UUID.uuid4()

      assert %State{players: [player]} = Quizzes.add_player(state, player_id, "Joe")
      assert %Player{name: "Joe", id: ^player_id} = player
    end

    test "sets first player to the host" do
      state = state_fixture()
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      assert %{players: [joe, jane]} =
               state
               |> Quizzes.add_player(player1_id, "Joe")
               |> Quizzes.add_player(player2_id, "Jane")

      assert joe.is_host == true
      assert jane.is_host == false
    end
  end

  describe "answer_question/3" do
    test "sets the current_answer for the specified player" do
      state = state_fixture()
      player1_id = UUID.uuid4()

      state = %{players: [player1]} = Quizzes.add_player(state, player1_id, "Joe")
      assert player1.current_answer == nil

      %{players: [player1]} = Quizzes.answer_question(state, player1_id, 1)
      assert player1.current_answer == 1
    end
  end

  describe "next_question/1" do
    test "increments the current question" do
      state = state_fixture()
      assert state.current_question == 0

      state = Quizzes.next_question(state)
      assert state.current_question == 1
    end

    test "updates each player's score and resets their current answer" do
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      state =
        state_fixture()
        |> Quizzes.add_player(player1_id, "Leonardo")
        |> Quizzes.add_player(player2_id, "Donatello")
        |> Quizzes.answer_question(player1_id, 0)
        |> Quizzes.answer_question(player2_id, 1)
        |> Quizzes.next_question()

      assert state.current_question == 1
      assert [leo, don] = state.players
      assert leo.score == 1
      assert leo.current_answer == nil
      assert don.score == 0
      assert don.current_answer == nil
    end
  end

  defp state_fixture do
    attrs = %{
      title: "Marvel characters",
      questions: [
        %{
          text: "Who is the strongest Avenger?",
          answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
          correct_answer: 0,
          explanation: "Hulk is the strongest Avenger."
        },
        %{
          text: "Who is the smartest Avenger?",
          answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
          correct_answer: 2,
          explanation: "Iron Man is the smartest Avenger."
        }
      ]
    }

    {:ok, state} = Quizzes.create_quiz(attrs)
    state
  end
end
