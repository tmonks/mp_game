defmodule MPG.Quizzes.Session do
  use GenServer

  alias MPG.Quizzes
  alias MPG.Quizzes.State

  @doc """
  Starts the server.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Pings the server
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
  def handle_cast({:add_player, id, player_name}, state) do
    state = Quizzes.add_player(state, id, player_name)
    # broadcast_state_updated(state)
    {:noreply, state}
  end
end
