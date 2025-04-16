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

  describe "toggle/3" do
    test "sets the player_id of the specified cell" do
      state = Bingos.new()
      state = Bingos.add_player(state, "player1", "Alice")
      player = get_player(state, "player1")

      state = Bingos.toggle(state, 0, player)
      [cell | _] = state.cells
      assert cell.player_id == "player1"
    end

    test "only updates the specified cell" do
      state = Bingos.new()
      state = Bingos.add_player(state, "player1", "Alice")
      player = get_player(state, "player1")

      state = Bingos.toggle(state, 0, player)
      {[first_cell], rest_cells} = Enum.split(state.cells, 1)
      assert first_cell.player_id == "player1"
      assert Enum.all?(rest_cells, &(&1.player_id == nil))
    end
  end

  defp get_player(state, id) do
    Enum.find(state.players, &(&1.id == id))
  end
end
