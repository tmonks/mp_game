defmodule MPGWeb.ThingsLive do
  use MPGWeb, :live_view

  alias MPG.Generator
  alias MPG.Things
  alias MPG.Things.Session
  alias Phoenix.PubSub

  import Phoenix.HTML.Form, only: [options_for_select: 2]

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      :ok = PubSub.subscribe(MPG.PubSub, "things_session")
    end

    state = Session.get_state(:things_session)
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(session_id: session_id)
      |> assign(state: state)
      |> assign(page_title: "The Things Game")
      |> assign(primary_color: "bg-emerald-500")
      |> assign_player()
      |> assign_question_form("")

    {:ok, socket}
  end

  defp assign_question_form(socket, question) do
    fields = %{"question" => question}
    errors = get_errors(question)
    form = to_form(fields, errors: errors)
    assign(socket, new_question_form: form)
  end

  defp get_errors(question) do
    if question in ["", nil] do
      [question: {"Question can't be blank", []}]
    else
      []
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  defp assign_player(%{assigns: assigns} = socket) do
    case Things.get_player(assigns.state, assigns.session_id) do
      nil -> assign(socket, player: nil)
      player -> assign(socket, player: player)
    end
  end

  @impl true
  def handle_event("join", %{"player_name" => player_name}, socket) do
    session_id = socket.assigns.session_id
    Session.add_player(:things_session, session_id, player_name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    Session.set_player_answer(:things_session, socket.assigns.session_id, answer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("reveal", %{"guesser_id" => guesser_id}, socket) do
    Session.reveal_player(:things_session, socket.assigns.session_id, guesser_id)
    {:noreply, push_patch(socket, to: ~p"/things")}
  end

  @impl true
  def handle_event("generate_question", _, socket) do
    question = Generator.random_thing()
    {:noreply, assign_question_form(socket, question)}
  end

  @impl true
  def handle_event("validate_new_question", %{"question" => question}, socket) do
    {:noreply, assign_question_form(socket, question)}
  end

  @impl true
  def handle_event("set_new_question", %{"question" => question}, socket) do
    Session.new_question(:things_session, question)

    {:noreply,
     socket
     |> assign_question_form("")
     |> push_patch(to: ~p"/things")}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    socket =
      socket
      |> assign(state: state)
      |> assign_player()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= unless assigns[:player] do %>
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
      <!-- CURRENT TOPIC -->
      <div class="mt-2 mb-8">
        <%= if is_nil(@state.topic) do %>
          <div id="waiting-message" class="text-gray-600 text-2xl">
            Waiting for the game to begin...
          </div>
        <% else %>
          <div id="current-question" class="text-gray-600 text-2xl">
            Things... <%= @state.topic %>
          </div>
        <% end %>
      </div>
      <!-- PLAYER LIST -->
      <%= if Things.current_status(@state) != :complete do %>
        <div class="mb-8">
          <div id="player-list" class="flex gap-2">
            <%= for player <- Enum.filter(@state.players, & !&1.revealed) do %>
              <.player_avatar
                player={player}
                show_answer_status={Things.current_status(@state) == :answering}
              />
            <% end %>
          </div>
        </div>
      <% end %>
      <!-- NEW QUESTION MODAL -->
      <.modal
        :if={
          @live_action == :new_question or (@player.is_host and Things.current_status(@state) == :new)
        }
        id="new-question-modal"
        show={true}
        on_cancel={JS.patch("/things")}
      >
        <div class="font-bold mb-4">Things...</div>
        <.form
          for={@new_question_form}
          id="new-question-form"
          phx-change="validate_new_question"
          phx-submit="set_new_question"
        >
          <div class="flex flex-col gap-4">
            <.input
              type="text"
              field={@new_question_form[:question]}
              class="flex-1 shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
            <a
              id="generate-question-button"
              phx-click="generate_question"
              class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded text-center cursor-pointer"
            >
              Generate <.icon name="hero-sparkles-solid" class="h-5 w-5" />
            </a>
            <button
              disabled={length(@new_question_form.errors) > 0}
              class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded"
            >
              Submit
            </button>
          </div>
        </.form>
      </.modal>
      <!-- ANSWERS LIST -->
      <div>
        <%= if Things.all_players_answered?(@state) do %>
          <div id="answers" class="bg-white shadow-md rounded-md overflow-hidden">
            <div class="bg-gray-100 py-2 px-4">
              <h2 class="text-xl font-semibold text-gray-800">Answers</h2>
            </div>
            <ul class="divide-y divide-gray-200">
              <div>
                <%= for player <- Enum.shuffle(@state.players) do %>
                  <.player_answer player={player} />
                <% end %>
              </div>
            </ul>
          </div>
        <% end %>
      </div>
      <!-- PLAYER CONTROLS -->
      <div class="flex flex-col mt-6 gap-4">
        <%= if @player.current_answer do %>
          <div class="flex flex-col gap-6">
            <div class="p-2">
              <div class="block text-xl font-bold text-gray-700 mb-2">
                My answer
              </div>
              <div id="my-answer" class="text-gray-600 text-base">
                <%= @player.current_answer %>
              </div>
            </div>
            <%= if Things.all_players_answered?(@state) and !is_nil(@player) and !@player.revealed do %>
              <.link
                id="reveal-button"
                class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded"
                patch={~p"/things/reveal"}
              >
                Reveal my answer
              </.link>
            <% end %>
          </div>
        <% end %>
        <!-- ANSWER FORM -->
        <%= if is_nil(@player.current_answer) and !is_nil(@state.topic) do %>
          <form id="answer-form" phx-submit="submit_answer">
            <div class="flex flex-col gap-4">
              <div>
                <label class="block text-gray-700 text-xl font-bold mb-2" for="answer">
                  My answer
                </label>
                <input
                  type="text"
                  name="answer"
                  class="flex-1 shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                />
              </div>
              <button class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded">
                Submit
              </button>
            </div>
          </form>
        <% end %>
        <!-- HOST NEXT QUESTION BUTTON -->
        <%= if @player.is_host and Things.current_status(@state) == :complete do %>
          <.link
            id="new-question-button"
            class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded text-center"
            patch={~p"/things/new_question"}
          >
            Next Question <.icon name="hero-arrow-path" class="h-5 w-5" />
          </.link>
        <% end %>
        <!-- REVEALED MODAL -->
        <.modal
          :if={@live_action == :reveal}
          id="reveal-modal"
          show={true}
          on_cancel={JS.patch("/things")}
        >
          <form id="reveal-form" phx-submit="reveal" class="flex flex-col gap-6">
            <div class="font-bold">Who guessed your answer?</div>
            <select
              id="guesser-select"
              name="guesser_id"
              class="flex-auto block appearance-none bg-white border border-gray-400 hover:border-gray-500 px-4 py-2 pr-8 rounded shadow leading-tight focus:outline-none focus:shadow-outline"
            >
              <%= options_for_select(player_options(@state.players, @player), []) %>
            </select>
            <button class="bg-emerald-500 hover:bg-emerald-700 text-white font-bold py-2 px-4 rounded">
              Submit
            </button>
          </form>
        </.modal>
      </div>
    <% end %>
    """
  end

  defp player_options(all_players, current_player) do
    all_players
    |> Enum.reject(&(&1.id == current_player.id))
    |> Enum.map(&{&1.name, &1.id})
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp player_avatar(assigns) do
    ~H"""
    <div
      class="relative flex flex-col items-center justify-center w-12 h-12 text-white font-bold rounded-full"
      data-role="avatar"
      style={"background-color: #{@player.color}"}
      id={"player-" <> @player.id}
    >
      <span class="relative top-1"><%= String.slice(assigns.player.name, 0..2) %></span>
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
      <div data-role="score" class="w-4 h-4 text-center text-sm">
        <%= @player.score || 0 %>
      </div>
    </div>
    """
  end

  defp player_answer(assigns) do
    ~H"""
    <li id={"answer-#{@player.id}"} class="flex items-center py-2 px-6 gap-2">
      <p class="text-gray-600 text-base"><%= @player.current_answer %></p>
      <%= if @player.revealed do %>
        <.player_avatar player={@player} show_answer_status={false} />
      <% end %>
    </li>
    """
  end
end
