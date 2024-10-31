defmodule MPG.Quizzes.State do
  use Ecto.Schema

  alias MPG.Quizzes.Player
  alias MPG.Quizzes.Question

  embedded_schema do
    field :title, :string
    field :current_question, :integer
    embeds_many :players, Player
    embeds_many :questions, Question
  end
end
