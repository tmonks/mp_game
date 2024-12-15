defmodule MPGWeb.QuizLive do
  use MPGWeb, :live_view
  use Phoenix.Component

  alias MPG.Quizzes
  alias MPG.Quizzes.Player
  alias MPG.Quizzes.Question
  alias MPG.Quizzes.Session
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      :ok = PubSub.subscribe(MPG.PubSub, "quiz_session")
    end

    state = Session.get_state(:quiz_session)
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(session_id: session_id)
      |> assign(state: state)
      |> assign_current_status()
      |> assign_player()

    {:ok, socket}
  end

  defp assign_player(%{assigns: assigns} = socket) do
    player = Quizzes.get_player(assigns.state, assigns.session_id)
    assign(socket, player: player)
  end

  defp assign_current_status(%{assigns: assigns} = socket) do
    quiz_status = Quizzes.current_status(assigns.state)
    assign(socket, quiz_status: quiz_status)
  end

  @impl true
  def handle_event("join", %{"player_name" => player_name}, socket) do
    session_id = socket.assigns.session_id
    Session.add_player(:quiz_session, session_id, player_name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("new_quiz", %{"title" => title}, socket) do
    Session.create_quiz(:quiz_session, title)
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_question", _params, socket) do
    Session.next_question(:quiz_session)
    {:noreply, socket}
  end

  @impl true
  def handle_event("answer_question", %{"answer" => answer}, socket) do
    answer = String.to_integer(answer)
    Session.answer_question(:quiz_session, socket.assigns.session_id, answer)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    # IO.inspect(state)

    socket =
      socket
      |> assign(state: state)
      |> assign_current_status()
      |> assign_player()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- JOIN FORM -->
    <%= if assigns[:player] == nil do %>
      <form id="join-form" phx-submit="join">
        <div class="flex gap-4 pt-16">
          <div>
            <input
              type="text"
              name="player_name"
              placeholder="Name"
              class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
          </div>
          <div>
            <button class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded">
              Join
            </button>
          </div>
        </div>
      </form>
    <% else %>
      <!-- NEW QUIZ MODAL -->
      <.modal
        :if={
          @live_action == :new_quiz or (@player.is_host and Quizzes.current_status(@state) == :new)
        }
        id="new-quiz-modal"
        show={true}
        on_cancel={JS.patch("/")}
      >
        <div class="font-bold mb-4">Quiz Title</div>
        <form id="new-quiz-form" phx-submit="new_quiz">
          <div class="flex flex-col gap-4">
            <input
              type="text"
              name="title"
              value=""
              class="flex-1 shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
            <button class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded">
              Submit
            </button>
          </div>
        </form>
      </.modal>
      <!-- QUIZ TITLE -->
      <div id="quiz-title" class="text-gray-600 text-2xl font-bold mb-4">
        <%= @state.title %>
      </div>
      <!-- STATUS MESSAGE -->
      <.status_message quiz_status={@quiz_status} />
      <!-- PLAYER LIST -->
      <div class="mb-8">
        <div id="player-list" class="flex gap-2">
          <%= for player <- @state.players do %>
            <.player_avatar player={player} show_answer_status={@quiz_status == :answering} />
          <% end %>
        </div>
      </div>
      <!-- QUESTION -->
      <%= if Quizzes.current_status(@state) in [:answering, :reviewing] do %>
        <.question_component
          question={@state.questions |> Enum.at(@state.current_question)}
          current_answer={@player.current_answer}
          players={@state.players}
        />
      <% end %>
      <!-- HOST CONTROLS -->
      <%= if @player.is_host and Quizzes.current_status(@state) in [:joining, :reviewing] do %>
        <button
          id="next-button"
          phx-click="next_question"
          class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded"
        >
          Next Question
        </button>
      <% end %>
    <% end %>
    """
  end

  attr :question, Question, required: true
  attr :current_answer, :boolean, default: nil
  attr :players, :list, default: []

  defp question_component(%{current_answer: nil} = assigns) do
    ~H"""
    <div id="question">
      <div id="question-text" class="text-gray-700 text-xl mb-4">
        <%= @question.text %>
      </div>
      <!-- ANSWERS -->
      <div id="answers" class="flex flex-col gap-4">
        <%= for {answer, i} <- Enum.with_index(@question.answers) do %>
          <button
            id={"answer-#{i}"}
            phx-click="answer_question"
            phx-value-answer={i}
            class="bg-gray-200 hover:bg-gray-300 text-gray-800 py-2 px-4 rounded text-left"
          >
            <%= answer %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp question_component(assigns) do
    ~H"""
    <div id="question" class="my-6">
      <div id="question-text" class="text-gray-700 text-xl mb-4">
        <%= @question.text %>
      </div>
      <!-- ANSWERS -->
      <div id="answers" class="flex flex-col gap-4">
        <%= for {answer, i} <- Enum.with_index(@question.answers) do %>
          <.answer_component
            answer={answer}
            index={i}
            status={get_answer_status(i, @question.correct_answer, @current_answer)}
            players={@players}
          />
        <% end %>
      </div>
      <!-- EXPLANATION -->
      <%= if @current_answer == @question.correct_answer do %>
        <div id="explanation" class="mt-6">
          <span class="font-medium text-green-600">Correct!</span> <%= @question.explanation %>
        </div>
      <% else %>
        <div id="explanation" class="mt-6">
          <span class="font-medium text-red-600">Incorrect.</span> <%= @question.explanation %>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_answer_status(index, correct_answer, players_answer) do
    cond do
      index == correct_answer -> :correct
      index == players_answer -> :incorrect
      true -> :not_selected
    end
  end

  attr :answer, :string, required: true
  attr :index, :integer, required: true
  attr :status, :atom, default: :not_selected
  attr :players, :list, default: []

  defp answer_component(assigns) do
    ~H"""
    <div
      id={"answer-#{@index}"}
      class={"py-2 px-4 rounded text-left flex items-center gap-2 #{classes_for_answer_status(@status)}"}
      data-role={@status}
    >
      <div><%= @answer %></div>
      <!-- player markers for players with this answer -->
      <%= for player <- Enum.filter(@players, & &1.current_answer == @index) do %>
        <.player_marker player={player} />
      <% end %>
    </div>
    """
  end

  defp classes_for_answer_status(:correct), do: "bg-teal-100 text-teal-900 font-bold"
  defp classes_for_answer_status(:incorrect), do: "bg-red-100 text-red-700"
  defp classes_for_answer_status(_), do: "bg-gray-200 text-gray-800"

  defp status_message(assigns) do
    ~H"""
    <div id="current-status" class="text-gray-600 text-xl mb-4">
      <%= case assigns.quiz_status do
        :new -> "Waiting for the host to set the quiz topic..."
        :generating -> "Generating quiz..."
        :joining -> "Waiting for players to join..."
        _ -> nil
      end %>
    </div>
    """
  end

  attr :player, Player, required: true
  attr :size, :integer, default: 12
  attr :show_answer_status, :boolean, default: false

  defp player_avatar(assigns) do
    ~H"""
    <div
      class={"relative flex items-center justify-center w-#{@size} h-#{@size} text-white font-bold rounded-full"}
      data-role="avatar"
      style={"background-color: #{@player.color}"}
      id={"player-" <> @player.id}
    >
      <%= String.slice(@player.name, 0..2) %>
      <%= if @player.current_answer != nil and @show_answer_status do %>
        <div
          data-role="ready-check-mark"
          class="absolute top-0 right-0 w-4 h-4 bg-green-500 rounded-full flex items-center justify-center"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-3 w-3 text-white"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
        </div>
      <% end %>
    </div>
    """
  end

  attr :player, Player, required: true

  defp player_marker(assigns) do
    ~H"""
    <div
      class="relative flex items-center justify-center w-7 h-7 text-xs text-white font-bold rounded-full"
      data-role="avatar"
      style={"background-color: #{@player.color}"}
      id={"player-marker-" <> @player.id}
    >
      <%= String.slice(@player.name, 0..2) %>
    </div>
    """
  end
end
