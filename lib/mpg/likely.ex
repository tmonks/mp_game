defmodule MPG.Likely do
  alias MPG.Likely.Player
  alias MPG.Likely.Question
  alias MPG.Likely.State

  @doc """
  Marks the game as started (triggers question generation)
  """
  def start_game(%State{} = state) do
    %State{state | started: true}
  end

  @doc """
  Sets the questions for the game
  """
  def set_questions(%State{} = state, questions) do
    %State{state | questions: Enum.map(questions, &struct(Question, &1))}
  end

  @doc """
  Adds a player to the state
  """
  def add_player(%State{} = state, id, name) do
    player_num = Enum.count(state.players)
    is_host = Enum.empty?(state.players)

    player = %Player{
      id: id,
      name: name,
      color: get_color_for_player(player_num),
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

    num = rem(num, length(colors))
    Enum.at(colors, num)
  end

  @doc """
  Sets the current vote for the specified player.
  `voted_for_id` is the session ID of the player being voted for.
  """
  def cast_vote(%State{} = state, player_id, voted_for_id) do
    players =
      Enum.map(state.players, fn
        %Player{id: ^player_id} = player -> %Player{player | current_vote: voted_for_id}
        player -> player
      end)

    state = %State{state | players: players}

    # Update the running tally in results for the current question
    %State{state | results: Map.put(state.results, state.current_question, tally_votes(state))}
  end

  @doc """
  Advances to the next question.
  If current_question is nil (first call from :joining), sets it to 0.
  Otherwise, tallies votes into results, clears current_vote, and increments.
  """
  def next_question(%{current_question: nil} = state), do: %{state | current_question: 0}

  def next_question(%State{} = state) do
    players = Enum.map(state.players, fn %Player{} = p -> %Player{p | current_vote: nil} end)

    %State{
      state
      | players: players,
        current_question: state.current_question + 1
    }
  end

  @doc """
  Sets the roasts map on state
  """
  def set_roasts(%State{} = state, roasts) do
    %State{state | roasts: roasts}
  end

  @doc """
  Returns the current status of the game
  """
  def current_status(state) do
    cond do
      !state.started ->
        :new

      length(state.questions) == 0 ->
        :generating

      state.current_question == nil ->
        :joining

      state.current_question > length(state.questions) - 1 and map_size(state.roasts) == 0 ->
        :roasting

      state.current_question > length(state.questions) - 1 ->
        :complete

      !all_players_voted?(state) ->
        :voting

      true ->
        :revealing
    end
  end

  @doc """
  Checks if all players have voted on the current question
  """
  def all_players_voted?(%State{players: players}) do
    Enum.all?(players, &(&1.current_vote != nil))
  end

  @doc """
  Retrieves a player with the given id
  """
  def get_player(state, id) do
    Enum.find(state.players, &(&1.id == id))
  end

  @doc """
  Tallies votes for the current question.
  Returns a map of %{player_id => vote_count}.
  """
  def tally_votes(%State{players: players}) do
    players
    |> Enum.map(& &1.current_vote)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  @doc """
  Returns the stored results for a given question index as a sorted list
  of {player, vote_count} tuples, sorted by vote count descending.
  """
  def vote_results_for_question(%State{} = state, question_index) do
    vote_tally = Map.get(state.results, question_index, %{})

    state.players
    |> Enum.map(fn player ->
      {player, Map.get(vote_tally, player.id, 0)}
    end)
    |> Enum.sort_by(fn {_player, count} -> count end, :desc)
  end

  @doc """
  Builds a summary of vote results for roast generation.
  Returns a list of {player_name, player_id, [question_texts]} for each player.
  """
  def vote_summary(%State{} = state) do
    state.players
    |> Enum.map(fn player ->
      won_questions =
        state.results
        |> Enum.filter(fn {_q_idx, tally} ->
          # player had the most votes for this question
          max_votes = tally |> Map.values() |> Enum.max(fn -> 0 end)
          max_votes > 0 and Map.get(tally, player.id, 0) == max_votes
        end)
        |> Enum.map(fn {q_idx, _tally} ->
          Enum.at(state.questions, q_idx).text
        end)

      {player.name, player.id, won_questions}
    end)
  end
end
