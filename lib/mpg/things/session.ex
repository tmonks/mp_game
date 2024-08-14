defmodule MPG.Things.Session do
  use GenServer

  alias MPG.Things
  alias MPG.Things.State

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
  def add_player(server, player_name) do
    GenServer.cast(server, {:add_player, player_name})
  end

  @doc """
  Sets a player's answer.
  """
  def set_player_answer(server, player_name, answer) do
    GenServer.cast(server, {:set_player_answer, player_name, answer})
  end

  @doc """
  Sets a new question and resets all player answers.
  """
  def new_question(server, topic) do
    GenServer.cast(server, {:new_question, topic})
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
  def handle_cast({:add_player, player_name}, state) do
    state = Things.add_player(state, player_name)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_player_answer, player_name, answer}, state) do
    state = Things.set_player_answer(state, player_name, answer)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_question, topic}, state) do
    state = Things.new_question(state, topic)
    {:noreply, state}
  end
end
