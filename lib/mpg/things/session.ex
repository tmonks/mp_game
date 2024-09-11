defmodule MPG.Things.Session do
  use GenServer

  alias MPG.Things
  alias MPG.Things.State
  alias Phoenix.PubSub

  @doc """
  Starts the server.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Pings the server.
  """
  def ping(server) do
    GenServer.call(server, :ping)
  end

  @doc """
  Retrieves the state.
  """
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Adds a player to the state.
  """
  def add_player(server, id, player_name) do
    GenServer.cast(server, {:add_player, id, player_name})
  end

  @doc """
  Sets a player's answer.
  """
  def set_player_answer(server, player_id, answer) do
    GenServer.cast(server, {:set_player_answer, player_id, answer})
  end

  @doc """
  Sets player to revealed.
  """
  def set_player_to_revealed(server, player_id) do
    GenServer.cast(server, {:set_player_to_revealed, player_id})
  end

  @doc """
  Sets a new question and resets all player answers.
  """
  def new_question(server, topic) do
    GenServer.cast(server, {:new_question, topic})
  end

  @doc """
  Returns true if all players have answered.
  """
  def all_players_answered?(server) do
    GenServer.call(server, :all_players_answered)
  end

  @impl true
  def init(:ok) do
    {:ok, %State{players: []}}
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
  def handle_cast({:set_player_to_revealed, player_id}, state) do
    state = Things.set_player_to_revealed(state, player_id)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  defp broadcast_state_updated(state) do
    PubSub.broadcast(MPG.PubSub, "things_session", {:state_updated, state})
  end
end
