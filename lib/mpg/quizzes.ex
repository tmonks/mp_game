defmodule MPG.Quizzes do
  alias MPG.Quizzes.State
  alias MPG.Quizzes.Question

  def create_quiz(attrs) do
    {:ok,
     %State{
       title: attrs.title,
       questions: Enum.map(attrs.questions, &struct(Question, &1))
     }}
  end
end
