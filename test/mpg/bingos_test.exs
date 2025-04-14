defmodule MPG.BingosTest do
  use ExUnit.Case, async: true

  alias MPG.Bingos
  alias MPG.Bingos.Cell
  alias MPG.Bingos.State

  describe "new/0" do
    test "returns a new randomized bingo board with 25 cells" do
      state = Bingos.new()

      assert %State{players: [], cells: cells} = state
      assert length(cells) == 25
      assert Enum.all?(cells, &match?(%Cell{}, &1))
      assert Enum.all?(cells, &(&1.toggled == false))
      assert Enum.all?(cells, &(&1.toggled_by == nil))
    end
  end
end
