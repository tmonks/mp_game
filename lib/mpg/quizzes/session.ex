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
  Generates a new quiz.
  """
  def create_quiz(server, title) do
    GenServer.cast(server, {:create_quiz, title})
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
  def handle_cast({:create_quiz, title}, _state) do
    quiz_attrs = generate_quiz(title)
    {:ok, state} = Quizzes.create_quiz(quiz_attrs)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_player, id, player_name}, state) do
    state = Quizzes.add_player(state, id, player_name)
    # broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:answer_question, player_id, answer}, state) do
    state = Quizzes.answer_question(state, player_id, answer)
    # broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:next_question, state) do
    state = Quizzes.next_question(state)
    # broadcast_state_updated(state)
    {:noreply, state}
  end

  defp generate_quiz(title) do
    """
    {
    "title": "Marvel Cinematic Universe Movie Trivia",
    "questions": [
    {
      "text": "What is the first film in the Marvel Cinematic Universe?",
      "answers": ["Iron Man", "Captain America: The First Avenger", "The Incredible Hulk", "Thor"],
      "correct_answer": 0,
      "explanation": "Iron Man (2008) kicked off the Marvel Cinematic Universe."
    },
    {
      "text": "Which Infinity Stone is first introduced in the MCU?",
      "answers": ["Power Stone", "Space Stone", "Mind Stone", "Reality Stone"],
      "correct_answer": 1,
      "explanation": "The Space Stone, hidden inside the Tesseract, is the first Infinity Stone introduced in Captain America: The First Avenger."
    },
    {
      "text": "Who is Tony Stark's father?",
      "answers": ["Howard Stark", "Obadiah Stane", "James Rhodes", "Nick Fury"],
      "correct_answer": 0,
      "explanation": "Howard Stark is Tony Stark's father and a founding member of S.H.I.E.L.D."
    },
    {
      "text": "In which film does Spider-Man make his first appearance in the MCU?",
      "answers": ["Spider-Man: Homecoming", "Avengers: Age of Ultron", "Captain America: Civil War", "Iron Man 3"],
      "correct_answer": 2,
      "explanation": "Spider-Man makes his first MCU appearance in Captain America: Civil War."
    },
    {
      "text": "What planet is Thor from?",
      "answers": ["Midgard", "Asgard", "Vanaheim", "Jotunheim"],
      "correct_answer": 1,
      "explanation": "Thor is from Asgard, the home of the Norse gods."
    },
    {
      "text": "Who is the director of S.H.I.E.L.D. when the Avengers first assemble?",
      "answers": ["Maria Hill", "Nick Fury", "Phil Coulson", "Alexander Pierce"],
      "correct_answer": 1,
      "explanation": "Nick Fury is the director of S.H.I.E.L.D. and brings the Avengers together."
    },
    {
      "text": "What type of doctor is Stephen Strange?",
      "answers": ["Neurosurgeon", "Cardiologist", "Orthopedic Surgeon", "Oncologist"],
      "correct_answer": 0,
      "explanation": "Stephen Strange is a skilled neurosurgeon before becoming the Sorcerer Supreme."
    },
    {
      "text": "Which Avenger has a twin sibling who dies in Avengers: Age of Ultron?",
      "answers": ["Thor", "Black Widow", "Scarlet Witch", "Hawkeye"],
      "correct_answer": 2,
      "explanation": "Scarlet Witch's twin brother, Quicksilver, dies in Avengers: Age of Ultron."
    },
    {
      "text": "What is the name of the realm where Hela was imprisoned?",
      "answers": ["Nidavellir", "Hel", "Vanaheim", "Sakaar"],
      "correct_answer": 1,
      "explanation": "Hela was imprisoned in Hel, a realm within Norse mythology."
    },
    {
      "text": "What is the name of the AI created by Tony Stark and Bruce Banner in Avengers: Age of Ultron?",
      "answers": ["Jarvis", "Ultron", "Friday", "Vision"],
      "correct_answer": 1,
      "explanation": "Ultron is the AI created by Tony Stark and Bruce Banner that turns against them."
    }
    ]
    }
    """
    |> Jason.decode!(keys: :atoms)
    |> Map.put(:title, title)
  end
end
