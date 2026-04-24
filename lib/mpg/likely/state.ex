defmodule MPG.Likely.State do
  use Ecto.Schema

  alias MPG.Likely.Player
  alias MPG.Likely.Question

  embedded_schema do
    field(:server_id, :string)
    field(:started, :boolean, default: false)
    field(:current_question, :integer)
    embeds_many(:players, Player)
    embeds_many(:questions, Question)
    field(:results, :map, default: %{})
    field(:roasts, :map, default: %{})
  end
end
