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
      assert Enum.all?(cells, &(&1.player_id == nil))
    end
  end

  describe "add_player/3" do
    test "adds a player to the state" do
      state = Bingos.new()
      state = Bingos.add_player(state, "player1", "Alice")

      assert [%{id: "player1", name: "Alice"}] = state.players
    end

    test "assigns different colors to players" do
      state = Bingos.new()
      state = Bingos.add_player(state, "player1", "Alice")
      state = Bingos.add_player(state, "player2", "Bob")

      [player1, player2] = state.players
      assert player1.color != player2.color
    end
  end
end
