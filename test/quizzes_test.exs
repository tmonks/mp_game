defmodule MPG.QuizzesTest do
  use ExUnit.Case

  alias MPG.Quizzes
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
end
