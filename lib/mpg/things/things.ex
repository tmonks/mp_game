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
  Sets the player with player_id to revealed.
  Adds 1 to the guesser's score.
  """
  def reveal_player(state, player_id, guesser_id) do
    players =
      Enum.map(state.players, fn
        # set player to revealed
        %Player{id: ^player_id} = player ->
          %Player{player | revealed: true}

        # increment guesser's score
        %Player{id: ^guesser_id, score: score} = player ->
          %Player{player | score: (score || 0) + 1}

        player ->
          player
      end)

    %State{state | players: players}
  end

  @doc """
  Returns true if all players have answered
  """
  def all_players_answered?(%State{players: players}) do
    Enum.all?(players, &(&1.current_answer != nil))
  end

  @doc """
  Returns the current state of the game

  :new - The game has just started
  :answering - Players are answering the question
  :guessing - Players are guessing the answer
  :complete - All player answers have been revealed
  """
  def current_status(%State{players: players, topic: topic}) do
    cond do
      topic == nil -> :new
      Enum.any?(players, &(&1.current_answer == nil)) -> :answering
      Enum.any?(players, &(&1.revealed == false)) -> :guessing
      true -> :complete
    end
  end

  @doc """
  Removes the player with the specified id
  """
  def remove_player(%State{players: players} = state, id) do
    players = Enum.reject(players, &(&1.id == id))
    %State{state | players: players}
  end
end
