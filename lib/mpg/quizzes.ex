defmodule MPG.Quizzes do
  alias MPG.Quizzes.Player
  alias MPG.Quizzes.Question
  alias MPG.Quizzes.State

  @doc """
  Creates a new quiz state with the given attributes
  """
  def create_quiz(attrs) do
    {:ok,
     %State{
       title: attrs.title,
       current_question: 0,
       questions: Enum.map(attrs.questions, &struct(Question, &1))
     }}
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
      is_host: is_host,
      score: 0
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
  Sets the current answer for the specified player
  """
  def answer_question(state, player_id, answer) do
    players =
      Enum.map(state.players, fn
        %Player{id: ^player_id} = player -> %Player{player | current_answer: answer}
        player -> player
      end)

    %State{state | players: players}
  end

  @doc """
  Updates all players' scores based on the current question and moves to the next question
  """
  def next_question(state) do
    correct_answer = get_answer_for_current_question(state)
    players = Enum.map(state.players, &update_player_score(&1, correct_answer))

    %State{
      state
      | players: players,
        current_question: state.current_question + 1
    }
  end

  @doc """
  Returns the current state of the quiz
  """
  def current_state(state) do
    cond do
      state.title == nil -> :new
      length(state.questions) == 0 -> :generating
      state.current_question == nil -> :joining
      state.current_question > length(state.questions) - 1 -> :complete
      !all_players_answered?(state) -> :answering
      true -> :reviewing
    end
  end

  def all_players_answered?(%State{players: players}) do
    Enum.all?(players, &(&1.current_answer != nil))
  end

  defp get_answer_for_current_question(state) do
    state.questions
    |> Enum.at(state.current_question)
    |> Map.get(:correct_answer)
  end

  defp update_player_score(%Player{} = player, correct_answer) do
    new_score =
      if player.current_answer == correct_answer,
        do: player.score + 1,
        else: player.score

    %Player{player | score: new_score, current_answer: nil}
  end

  @doc """
  Retrieves a player with the given id
  """
  def get_player(state, id) do
    Enum.find(state.players, &(&1.id == id))
  end
end
