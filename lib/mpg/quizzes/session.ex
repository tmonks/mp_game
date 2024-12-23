defmodule MPG.Quizzes.Session do
  use GenServer

  alias MPG.Generator
  alias MPG.Quizzes
  alias MPG.Quizzes.State
  alias Phoenix.PubSub

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
  Generates a new quiz.
  """
  def create_quiz(server, title) do
    GenServer.cast(server, {:create_quiz, title})
  end

  @doc """
  Sets the questions for the quiz.
  """
  def set_questions(server, questions) do
    GenServer.cast(server, {:set_questions, questions})
  end

  @doc """
  Adds a player to the state.
  """
  def add_player(server, id, player_name) do
    GenServer.cast(server, {:add_player, id, player_name})
  end

  @doc """
  Set a player's answer.
  """
  def answer_question(server, player_id, answer) do
    GenServer.cast(server, {:answer_question, player_id, answer})
  end

  @doc """
  Progresses the state to the next question and updates players' scores
  """
  def next_question(server) do
    GenServer.cast(server, :next_question)
  end

  @doc """
  Sets the state manually for testing purposes.
  """
  def set_state(server, state) do
    GenServer.cast(server, {:set_state, state})
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
  def handle_cast({:create_quiz, title}, state) do
    state = Quizzes.initialize(state, title)
    server = self()

    # start a background task to generate the quiz questions
    Task.start(fn ->
      questions = Generator.generate_quiz_questions(title)
      GenServer.cast(server, {:set_questions, questions})
    end)

    broadcast_state_updated(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_questions, questions}, state) do
    state = Quizzes.set_questions(state, questions)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_player, id, player_name}, state) do
    state = Quizzes.add_player(state, id, player_name)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:answer_question, player_id, answer}, state) do
    state = Quizzes.answer_question(state, player_id, answer)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:next_question, state) do
    state = Quizzes.next_question(state)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_state, state}, _old_state) do
    broadcast_state_updated(state)
    {:noreply, state}
  end

  defp broadcast_state_updated(state) do
    PubSub.broadcast(MPG.PubSub, "quiz_session", {:state_updated, state})
  end
end
