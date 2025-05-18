defmodule MPG.BingosTest do
  use ExUnit.Case, async: true

  alias MPG.Bingos
  alias MPG.Bingos.Cell
  alias MPG.Bingos.State

  @server_id "bingos_test"

  describe "new/0" do
    test "returns a new bingo state" do
      state = Bingos.new(@server_id)

      assert %State{players: [], cells: []} = state
    end
  end

  describe "add_player/3" do
    test "adds a player to the state" do
      state = Bingos.new(@server_id)
      state = Bingos.add_player(state, "player1", "Alice")

      assert [%{id: "player1", name: "Alice"}] = state.players
    end

    test "assigns different colors to players" do
      state = Bingos.new(@server_id)
      state = Bingos.add_player(state, "player1", "Alice")
      state = Bingos.add_player(state, "player2", "Bob")

      [player1, player2] = state.players
      assert player1.color != player2.color
    end
  end

  describe "toggle/3" do
    test "sets the player_id of the specified cell" do
      state = Bingos.new(@server_id)
      state = Bingos.update_cells(state, make_cells())
      state = Bingos.add_player(state, "player1", "Alice")

      state = Bingos.toggle(state, 0, "player1")
      [cell | _] = state.cells
      assert cell.player_id == "player1"
    end

    test "only updates the specified cell" do
      state = Bingos.new(@server_id)
      state = Bingos.update_cells(state, make_cells())
      state = Bingos.add_player(state, "player1", "Alice")

      state = Bingos.toggle(state, 0, "player1")
      {[first_cell], rest_cells} = Enum.split(state.cells, 1)
      assert first_cell.player_id == "player1"
      assert Enum.all?(rest_cells, &(&1.player_id == nil))
    end

    test "untoggles a cell if it's already toggled" do
      state = Bingos.new(@server_id)
      state = Bingos.update_cells(state, make_cells())
      state = Bingos.add_player(state, "player1", "Alice")

      # First toggle
      state = Bingos.toggle(state, 0, "player1")
      [cell | _] = state.cells
      assert cell.player_id == "player1"

      # Second toggle (untoggle)
      state = Bingos.toggle(state, 0, "player1")
      [cell | _] = state.cells
      assert cell.player_id == nil
    end
  end

  describe "update_cells/2" do
    test "updates the state's cells with new strings" do
      state = Bingos.new(@server_id)
      new_cells = make_cells()

      updated_state = Bingos.update_cells(state, new_cells)

      assert length(updated_state.cells) == 25
      assert Enum.all?(updated_state.cells, &match?(%Cell{}, &1))
      assert Enum.all?(updated_state.cells, &(&1.player_id == nil))

      # Verify the cells have the new text
      Enum.each(updated_state.cells, fn cell ->
        assert String.starts_with?(cell.text, "Cell ")
      end)
    end
  end

  defp make_cells() do
    Enum.map(1..25, &"Cell #{&1}")
  end
end
