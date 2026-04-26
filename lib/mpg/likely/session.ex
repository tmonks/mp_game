defmodule MPG.Likely.Session do
  use GenServer

  alias MPG.Generator
  alias MPG.Likely
  alias MPG.Likely.State
  alias Phoenix.PubSub

  def child_spec(opts) do
    name = Keyword.get(opts, :name, "likely")

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
  Determines the Registry name ("via tuple") from a string id
  """
  def registered_name(id) do
    {:via, Registry, {MPG.GameRegistry, id, :likely}}
  end

  @doc """
  Pings the server
  """
  def ping(server_id) do
    registered_name(server_id)
    |> GenServer.call(:ping)
  end

  @doc """
  Retrieves the state.
  Returns an error tuple if the server cannot be found.
  """
  def get_state(server_id) do
    case Registry.lookup(MPG.GameRegistry, server_id) do
      [{_, _pid}] -> {:ok, registered_name(server_id) |> GenServer.call(:get_state)}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Starts the game by generating questions in the background.
  """
  def start_game(server_id) do
    registered_name(server_id)
    |> GenServer.cast(:start_game)
  end

  @doc """
  Sets the questions for the game.
  """
  def set_questions(server_id, questions) do
    registered_name(server_id)
    |> GenServer.cast({:set_questions, questions})
  end

  @doc """
  Adds a player to the state.
  """
  def add_player(server_id, player_id, player_name) do
    registered_name(server_id)
    |> GenServer.cast({:add_player, player_id, player_name})
  end

  @doc """
  Sets a player's vote.
  """
  def cast_vote(server_id, player_id, voted_for_id) do
    registered_name(server_id)
    |> GenServer.cast({:cast_vote, player_id, voted_for_id})
  end

  @doc """
  Progresses the state to the next question.
  If all questions are done, triggers roast generation.
  """
  def next_question(server_id) do
    registered_name(server_id)
    |> GenServer.cast(:next_question)
  end

  @doc """
  Sets the roasts on the state.
  """
  def set_roasts(server_id, roasts) do
    registered_name(server_id)
    |> GenServer.cast({:set_roasts, roasts})
  end

  @doc """
  Sets the state manually for testing purposes.
  """
  def set_state(server_id, state) do
    registered_name(server_id)
    |> GenServer.cast({:set_state, state})
  end

  @impl true
  def init(server_id) do
    {:ok, %State{server_id: server_id, players: [], questions: [], results: %{}, roasts: %{}}}
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
  def handle_cast(:start_game, state) do
    state = Likely.start_game(state)
    broadcast_state_updated(state, :start_game)

    server = registered_name(state.server_id)

    Task.start(fn ->
      questions = Generator.generate_likely_questions()
      GenServer.cast(server, {:set_questions, questions})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_questions, questions}, state) do
    state = Likely.set_questions(state, questions)
    broadcast_state_updated(state, :set_questions)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_player, id, player_name}, state) do
    state = Likely.add_player(state, id, player_name)
    broadcast_state_updated(state, :add_player)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:cast_vote, player_id, voted_for_id}, state) do
    state = Likely.cast_vote(state, player_id, voted_for_id)
    broadcast_state_updated(state, :cast_vote)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:next_question, state) do
    state = Likely.next_question(state)
    broadcast_state_updated(state, :next_question)

    if Likely.current_status(state) == :roasting do
      server = registered_name(state.server_id)
      vote_summary = Likely.vote_summary(state)

      Task.start(fn ->
        roasts = Generator.generate_likely_roasts(vote_summary)
        GenServer.cast(server, {:set_roasts, roasts})
      end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_roasts, roasts}, state) do
    state = Likely.set_roasts(state, roasts)
    broadcast_state_updated(state, :set_roasts)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_state, state}, _old_state) do
    broadcast_state_updated(state, :set_state)
    {:noreply, state}
  end

  defp broadcast_state_updated(state, action) do
    PubSub.broadcast(MPG.PubSub, state.server_id, {:state_updated, action, state})
  end
end
