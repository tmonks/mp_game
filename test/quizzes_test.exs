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

      assert {:ok, %State{title: "Marvel characters", questions: questions}} =
               Quizzes.create_quiz(attrs)

      assert [%Question{} = question] = questions
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

  defp state_fixture do
    %State{
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
  end
end
