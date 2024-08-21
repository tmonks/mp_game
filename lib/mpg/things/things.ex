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
    players = Enum.map(state.players, &%Player{&1 | current_answer: nil})

    %State{state | topic: topic, players: players}
  end

  def add_player(state, id, name) do
    player = %Player{id: id, name: name}
    %State{state | players: state.players ++ [player]}
  end

  def set_player_answer(state, player_name, answer) do
    players =
      Enum.map(state.players, fn
        %Player{name: ^player_name} = player -> %Player{player | current_answer: answer}
        player -> player
      end)

    %State{state | players: players}
  end
end
