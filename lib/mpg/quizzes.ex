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
      number_correct: 0
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
end
