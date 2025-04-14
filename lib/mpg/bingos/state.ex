defmodule MPG.Bingos.State do
  use Ecto.Schema

  alias MPG.Bingos.Player
  alias MPG.Bingos.Cell

  embedded_schema do
    embeds_many(:players, Player)
    embeds_many(:cells, Cell)
  end
end
