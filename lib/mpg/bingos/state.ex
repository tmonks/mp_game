defmodule MPG.Bingos.State do
  use Ecto.Schema

  alias MPG.Bingos.Player
  alias MPG.Bingos.Cell

  embedded_schema do
    field(:server_id, :string)
    field(:bingo_type, :string)
    embeds_many(:players, Player)
    embeds_many(:cells, Cell)
  end
end
