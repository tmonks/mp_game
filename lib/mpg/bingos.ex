defmodule MPG.Bingos do
  alias MPG.Bingos.State
  alias MPG.Bingos.Cell
  alias MPG.Bingos.Player

  @doc """
  Creates a new bingo game state with a randomized board of 25 cells
  """
  def new(server_id) do
    %State{
      server_id: server_id,
      players: [],
      cells: get_random_cells()
    }
  end

  @doc """
  Adds a player to the state
  """
  def add_player(state, id, name) do
    player_num = Enum.count(state.players)

    player = %Player{
      id: id,
      name: name,
      color: get_color_for_player(player_num)
    }

    %State{state | players: state.players ++ [player]}
  end

  @doc """
  Toggles the specified cell for the given player_id.
  If the cell is already toggled by the player, it will be untoggled.
  """
  def toggle(state, cell_index, player_id) do
    cells =
      state.cells
      |> Enum.with_index()
      |> Enum.map(fn
        {cell, ^cell_index} -> toggle_cell(cell, player_id)
        {cell, _} -> cell
      end)

    %State{state | cells: cells}
  end

  defp toggle_cell(%Cell{player_id: nil} = cell, player_id) do
    %Cell{cell | player_id: player_id}
  end

  defp toggle_cell(%Cell{player_id: player_id} = cell, player_id) do
    %Cell{cell | player_id: nil}
  end

  defp get_random_cells do
    cells()
    |> Enum.shuffle()
    |> Enum.take(25)
    |> Enum.map(&%Cell{text: &1, player_id: nil})
  end

  defp get_color_for_player(num) do
    colors = [
      "Gold",
      "DarkSlateBlue",
      "DeepPink",
      "DeepSkyBlue",
      "DarkOrange",
      "DarkViolet",
      "YellowGreen",
      "Teal"
    ]

    # start with 0, and wrap around if we go over the length of the list
    num = rem(num, length(colors))
    Enum.at(colors, num)
  end

  defp cells do
    [
      "Learned something interesting",
      "Had something funny happen to you",
      "Did something embarrassing",
      "Made someone laugh",
      "Did something kind for someone",
      "Tried a new food",
      "Got a new idea you're excited about",
      "Had an encounter with an animal",
      "Solved a problem",
      "Received a compliment",
      "Helped a friend or co-worker",
      "Learned a new word or phrase",
      "Faced a fear",
      "Noticed something beautiful",
      "Made a new friend or acquaintance",
      "Completed a goal or task",
      "Had a moment of relaxation",
      "Experienced a moment of gratitude",
      "Observed an act of kindness",
      "Learned from a mistake",
      "Felt inspired by something or someone",
      "Saw something new on the way to school/work",
      "Tried a new activity",
      "Had a meaningful conversation",
      "Overcame a challenge",
      "Changed an opinion about something",
      "Found something lost or thought was gone",
      "Saw or heard something weird",
      "Heard a new song that you really liked",
      "Read something interesting",
      "Gave someone advice",
      "Received some good advice",
      "Received unexpected good news",
      "Saw an impressive piece of art or creativity",
      "Adapted to a an unexpected change",
      "Dreamt something vivid or memorable",
      "Laughed at a joke or funny situation",
      "Recognized a personal improvement",
      "Found a new movie or TV show to watch",
      "Found a new recipe to try",
      "Did something creative",
      "Made progress on a big project or goal",
      "Learned something about a different culture",
      "Did something to help the environment"
    ]
  end
end
