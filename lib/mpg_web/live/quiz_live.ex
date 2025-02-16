defmodule MPGWeb.QuizLive do
  use MPGWeb, :live_view
  use Phoenix.Component

  alias MPG.Generator
  alias MPG.Quizzes
  alias MPG.Quizzes.Player
  alias MPG.Quizzes.Question
  alias MPG.Quizzes.Session
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(page_title: "Quizoots!")
      |> assign(primary_color: "bg-violet-500")
      |> assign(session_id: session_id)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => server_id}, _url, socket) do
    socket =
      case Session.get_state(server_id) do
        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Game not found")
          |> push_navigate(to: ~p"/")

        {:ok, state} ->
          :ok = PubSub.subscribe(MPG.PubSub, server_id)

          socket
          |> assign(server_id: server_id)
          |> assign(state: state)
          |> assign_current_status()
          |> assign_player()
          |> assign_quiz_topic_form("")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # generate a random 5 digit server ID
    server_id = Enum.random(10000..99999) |> Integer.to_string()

    {:ok, _pid} =
      DynamicSupervisor.start_child(MPG.GameSupervisor, {Session, name: server_id})

    {:noreply, push_patch(socket, to: ~p"/quiz/#{server_id}")}
  end

  defp assign_quiz_topic_form(socket, topic) do
    errors = verify_not_empty(topic)
    form = to_form(%{"topic" => topic}, errors: errors)
    assign(socket, quiz_topic_form: form)
  end

  defp maybe_show_new_quiz_form(%{assigns: %{live_action: :new_quiz}} = socket), do: socket

  defp maybe_show_new_quiz_form(socket) do
    %{player: player, quiz_status: quiz_status} = socket.assigns

    if !is_nil(player) and player.is_host and quiz_status == :new do
      push_patch(socket, to: ~p"/quiz/#{socket.assigns.server_id}/new_quiz")
    else
      socket
    end
  end

  defp verify_not_empty(topic) do
    if topic in ["", nil] do
      [topic: {"Topic can't be blank", []}]
    else
      []
    end
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
    %{session_id: session_id, server_id: server_id} = socket.assigns
    Session.add_player(server_id, session_id, player_name)
    {:noreply, socket}
  end

  def handle_event("validate_quiz_topic", %{"topic" => topic}, socket) do
    {:noreply, assign_quiz_topic_form(socket, topic)}
  end

  def handle_event("generate_quiz_topic", _params, socket) do
    topic = Generator.random_quiz_topic()
    {:noreply, assign_quiz_topic_form(socket, topic)}
  end

  @impl true
  def handle_event("new_quiz_topic", %{"topic" => topic}, socket) do
    server_id = socket.assigns.server_id
    Session.create_quiz(server_id, topic)
    {:noreply, push_patch(socket, to: ~p"/quiz/#{server_id}")}
  end

  @impl true
  def handle_event("next_question", _params, socket) do
    server_id = socket.assigns.server_id
    Session.next_question(server_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("answer_question", %{"answer" => answer}, socket) do
    answer = String.to_integer(answer)
    server_id = socket.assigns.server_id
    Session.answer_question(server_id, socket.assigns.session_id, answer)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, _action, state}, socket) do
    socket =
      socket
      |> assign(state: state)
      |> assign_current_status()
      |> assign_player()
      |> maybe_show_new_quiz_form()

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
              placeholder="Enter your name"
              class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
          </div>
          <div>
            <button class="bg-violet-500 hover:bg-violet-700 text-white font-bold py-2 px-4 rounded">
              Submit
            </button>
          </div>
        </div>
      </form>
    <% else %>
      <!-- QUIZ TITLE -->
      <div id="quiz-title" class="text-gray-600 text-2xl font-bold mb-4">
        <%= @state.title %>
      </div>
      <!-- GAME CODE -->
      <%= if @quiz_status in [:new, :generating, :joining] do %>
        <div id="game-code" class="text-gray-600 text-lg mb-2">
          Game Code: <%= @server_id %>
        </div>
      <% end %>
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
      <!-- NEW QUIZ TOPIC FORM -->
      <%= if @live_action == :new_quiz do %>
        <.quiz_topic_form form={@quiz_topic_form} />
      <% end %>
      <!-- QUESTION -->
      <%= if Quizzes.current_status(@state) in [:answering, :reviewing] do %>
        <!-- QUESTION COUNTER -->
        <div id="question-counter" class="text-sm text-gray-600 mb-1">
          Question <%= @state.current_question + 1 %> of <%= length(@state.questions) %>
        </div>
        <.question_component
          question={@state.questions |> Enum.at(@state.current_question)}
          current_answer={@player.current_answer}
          players={@state.players}
        />
      <% end %>
      <!-- RESULTS -->
      <%= if Quizzes.current_status(@state) == :complete do %>
        <.results_component players={@state.players} question_quantity={length(@state.questions)} />
      <% end %>
      <!-- HOST NEXT QUESTION BUTTON -->
      <%= if @player.is_host and Quizzes.current_status(@state) in [:joining, :reviewing] do %>
        <button
          id="next-button"
          phx-click="next_question"
          class="bg-violet-500 hover:bg-violet-700 text-white font-bold py-2 px-4 rounded"
        >
          Next Question
        </button>
      <% end %>
      <!-- HOST NEW QUIZ BUTTON -->
      <%= if @player.is_host and Quizzes.current_status(@state) == :complete do %>
        <.link
          id="new-quiz-button"
          class="bg-violet-500 hover:bg-violet-700 text-white font-bold py-2 px-4 rounded"
          patch={~p"/quiz/#{@server_id}/new_quiz"}
        >
          New Quiz
        </.link>
      <% end %>
    <% end %>
    """
  end

  defp quiz_topic_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="quiz-topic-form"
      phx-submit="new_quiz_topic"
      phx-change="validate_quiz_topic"
    >
      <div class="font-bold mb-4">Quiz Topic</div>
      <div class="flex flex-col gap-4">
        <.input
          type="text"
          field={@form[:topic]}
          class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
        />
        <div class="flex gap-4 w-full">
          <a
            id="generate-topic-button"
            phx-click="generate_quiz_topic"
            class="flex-1 bg-violet-500 hover:bg-violet-700 text-white font-bold py-2 px-4 rounded text-center cursor-pointer"
          >
            Generate <.icon name="hero-sparkles-solid" class="h-5 w-5" />
          </a>
          <button class="flex-1 bg-violet-500 hover:bg-violet-700 text-white font-bold py-2 px-4 rounded">
            Submit
          </button>
        </div>
      </div>
    </.form>
    """
  end

  attr :question, Question, required: true
  attr :current_answer, :boolean, default: nil
  attr :players, :list, default: []

  defp question_component(%{current_answer: nil} = assigns) do
    ~H"""
    <div id="question">
      <div id="question-text" class="text-xl mb-6">
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
    <div id="question" class="mb-6">
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
          <span class="font-medium text-green-500 mr-2">
            <.icon name="hero-check-circle-solid" class="h-5 w-5 mb-2" /> Correct!
          </span>
          <%= @question.explanation %>
        </div>
      <% else %>
        <div id="explanation" class="mt-6">
          <span class="font-medium text-red-500 mr-2">
            <.icon name="hero-x-circle-solid" class="h-5 w-5 mb-1" /> Incorrect.
          </span>
          <%= @question.explanation %>
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
        :joining -> "Ready to start!"
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

  attr :players, :list, required: true
  attr :question_quantity, :integer, required: true

  defp results_component(assigns) do
    ~H"""
    <div id="results" class="bg-white shadow-md rounded-md overflow-hidden mb-8 max-w-20">
      <div class="bg-gray-100 py-2 px-4">
        <h2 class="text-xl font-semibold text-gray-800">Results</h2>
      </div>
      <ul class="divide-y divide-gray-200">
        <div>
          <%= for player <- Enum.sort(assigns.players, & &1.score > &2.score) do %>
            <li class="flex items-center justify-between py-2 px-4 gap-4">
              <div class="text-xl">
                <%= player.name %>
              </div>
              <div id={"score-#{player.id}"} class="text-xl font-bold">
                <%= format_score(player.score, @question_quantity) %>
              </div>
            </li>
          <% end %>
        </div>
      </ul>
    </div>
    """
  end

  # format score to a rounded percentage
  defp format_score(score, question_quantity) do
    score =
      (score / question_quantity)
      |> Kernel.*(100)
      |> Float.round(0)
      |> trunc

    "#{score}%"
  end
end
