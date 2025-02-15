defmodule MPG.Things.Session do
  use GenServer

  alias MPG.Things
  alias MPG.Things.State
  alias Phoenix.PubSub

  def child_spec(opts) do
    name = Keyword.get(opts, :name, "things")

    %{
      id: "#{__MODULE__}_#{name}",
      start: {__MODULE__, :start_link, [name]}
    }
  end

  @doc """
  Starts the server.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: registered_name(name))
  end

  @doc """
  Pings the server.
  """
  def ping(server_id) do
    registered_name(server_id)
    |> GenServer.call(:ping)
  end

  @doc """
  Retrieves the state.
  Returns {:ok, state} if the server is found, otherwise {:error, :not_found}.
  """
  def get_state(server_id) do
    case Registry.lookup(MPG.GameRegistry, server_id) do
      [{_, _pid}] -> {:ok, registered_name(server_id) |> GenServer.call(:get_state)}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Adds a player to the state.
  """
  def add_player(server_id, player_id, player_name) do
    registered_name(server_id)
    |> GenServer.cast({:add_player, player_id, player_name})
  end

  @doc """
  Sets a player's answer.
  """
  def set_player_answer(server_id, player_id, answer) do
    registered_name(server_id)
    |> GenServer.cast({:set_player_answer, player_id, answer})
  end

  @doc """
  Sets player to revealed.
  """
  def reveal_player(server_id, player_id, guesser_id) do
    registered_name(server_id)
    |> GenServer.cast({:reveal_player, player_id, guesser_id})
  end

  @doc """
  Sets a new question and resets all player answers.
  """
  def new_question(server_id, topic) do
    registered_name(server_id)
    |> GenServer.cast({:new_question, topic})
  end

  @doc """
  Removes player with the given id.
  """
  def remove_player(server_id, player_id) do
    registered_name(server_id)
    |> GenServer.cast({:remove_player, player_id})
  end

  @doc """
  Determines the Registry name ("via tuple") from a string id
  """
  def registered_name(id) do
    {:via, Registry, {MPG.GameRegistry, id, :things}}
  end

  @impl true
  def init(server_id) do
    {:ok, %State{server_id: server_id, players: []}}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:all_players_answered, _from, state) do
    {:reply, Enum.all?(state.players, &(&1.current_answer != nil)), state}
  end

  @impl true
  def handle_cast({:add_player, id, player_name}, state) do
    state = Things.add_player(state, id, player_name)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_player_answer, player_id, answer}, state) do
    state = Things.set_player_answer(state, player_id, answer)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_question, topic}, state) do
    state = Things.new_question(state, topic)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:reveal_player, player_id, guesser_id}, state) do
    state = Things.reveal_player(state, player_id, guesser_id)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove_player, player_id}, state) do
    state = Things.remove_player(state, player_id)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  defp broadcast_state_updated(state) do
    PubSub.broadcast(MPG.PubSub, state.server_id, {:state_updated, state})
  end
end
