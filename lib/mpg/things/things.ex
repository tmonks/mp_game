defmodule MPG.Things do
  alias MPG.Things.Player
  alias MPG.Things.State

  def new(topic) do
    %State{topic: topic, players: []}
  end

  @doc """
  Resets the topic and all player answers
  """
  def new_question(state, topic) do
    players = Enum.map(state.players, &%Player{&1 | current_answer: nil, revealed: false})

    %State{state | topic: topic, players: players}
  end

  @doc """
  Adds a player to the state
  """
  def add_player(state, id, name) do
    player_num = Enum.count(state.players)
    is_host = Enum.empty?(state.players)

    player = %Player{
      id: id,
      name: name,
      color: get_color_for_player(player_num),
      current_answer: nil,
      revealed: false,
      is_host: is_host
    }

    %State{state | players: state.players ++ [player]}
  end

  # gets a color in sequence starting with 0 (wraps back to 0)
  defp get_color_for_player(num) do
    colors = [
      "CadetBlue",
      "Crimson",
      "DarkMagenta",
      "DarkSlateBlue",
      "FireBrick",
      "Indigo",
      "LightSeaGreen",
      "RoyalBlue"
    ]

    # wrap back to 0 if num is greater than the length of colors
    num = rem(num, length(colors))
    Enum.at(colors, num)
  end

  @doc """
  Retrieves a player with the given id
  """
  def get_player(state, id) do
    Enum.find(state.players, &(&1.id == id))
  end

  @doc """
  Sets the current_answer for the specified player
  """
  def set_player_answer(state, player_id, answer) do
    players =
      Enum.map(state.players, fn
        %Player{id: ^player_id} = player -> %Player{player | current_answer: answer}
        player -> player
      end)

    %State{state | players: players}
  end

  @doc """
  Sets the player with the specified id to revealed
  """
  def set_player_to_revealed(state, id) do
    players =
      Enum.map(state.players, fn
        %Player{id: ^id} = player -> %Player{player | revealed: true}
        player -> player
      end)

    %State{state | players: players}
  end

  @doc """
  Returns true if all players have answered
  """
  def all_players_answered?(%State{players: players}) do
    Enum.all?(players, &(&1.current_answer != nil))
  end
end
