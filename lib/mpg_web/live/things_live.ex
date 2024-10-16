defmodule MPGWeb.ThingsLive do
  use MPGWeb, :live_view

  alias MPG.Things
  alias MPG.Things.Game
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      :ok = PubSub.subscribe(MPG.PubSub, "things_session")
    end

    state = Game.get_state(:things_session)
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(session_id: session_id)
      |> assign(state: state)
      |> assign_player()

    {:ok, socket}
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
    Game.add_player(:things_session, session_id, player_name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    Game.set_player_answer(:things_session, socket.assigns.session_id, answer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("reveal", _, socket) do
    Game.set_player_to_revealed(:things_session, socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_new_question", %{"question" => question}, socket) do
    Game.new_question(:things_session, question)

    {:noreply, push_patch(socket, to: "/")}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply, assign(socket, state: state) |> assign_player()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= unless assigns[:player] do %>
      <form id="join-form" phx-submit="join">
        <div class="flex gap-4">
          <div>
            <input
              type="text"
              name="player_name"
              placeholder="Name"
              class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
          </div>
          <div>
            <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
              Join
            </button>
          </div>
        </div>
      </form>
    <% else %>
      <div class="flex items-center gap-4">
        <h2 id="current-question" class="text-2xl text-gray-600">
          Things that are... <%= @state.topic %>?
        </h2>
      </div>

      <.modal
        :if={@live_action == :new_question}
        id="new-question-modal"
        show={true}
        on_cancel={JS.patch("/")}
      >
        <div class="font-bold mb-4">Things that are...</div>
        <form id="new-question-form" phx-submit="set_new_question">
          <div class="flex justify-between gap-4">
            <input
              type="text"
              name="question"
              value=""
              class="flex-1 shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
            <div>
              <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
                Submit
              </button>
            </div>
          </div>
        </form>
      </.modal>

      <div class="my-6">
        <div id="player-list" class="flex gap-2">
          <%= for player <- Enum.filter(@state.players, & !&1.revealed) do %>
            <.player_avatar player={player} />
          <% end %>
        </div>
      </div>
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
      <!-- player controls section -->
      <div class="flex flex-col mt-6 gap-4">
        <%= cond do %>
          <% is_nil(@state.topic) -> %>
            <div id="waiting-message" class="text-gray-600 text-base">
              Waiting for the game to begin...
            </div>
          <% @player.current_answer -> %>
            <div class="flex flex-col p-4 gap-6">
              <div>
                <div class="block text-gray-700 font-bold mb-2">
                  My answer
                </div>
                <div id="my-answer" class="text-gray-600 text-base">
                  <%= @player.current_answer %>
                </div>
              </div>
              <%= if Things.all_players_answered?(@state) and !is_nil(@player) and !@player.revealed do %>
                <button
                  id="reveal-button"
                  class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
                  phx-click="reveal"
                >
                  Reveal my answer
                </button>
              <% end %>
            </div>
          <% true -> %>
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
                <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
                  Submit
                </button>
              </div>
            </form>
        <% end %>
        <%= if @player.is_host do %>
          <.link
            id="new-question-button"
            class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded text-center"
            patch={~p"/new_question"}
          >
            Next Question <.icon name="hero-arrow-path" class="h-5 w-5" />
          </.link>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp player_avatar(assigns) do
    ~H"""
    <div
      class="relative flex items-center justify-center w-12 h-12 text-white font-bold rounded-full"
      data-role="avatar"
      style={"background-color: #{@player.color}"}
      id={"player-" <> @player.id}
    >
      <%= String.slice(assigns.player.name, 0..2) %>
      <%= if @player.current_answer do %>
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

  defp player_answer(assigns) do
    ~H"""
    <li id={"answer-#{@player.id}"} class="flex items-center py-4 px-6 gap-2">
      <p class="text-gray-600 text-base"><%= @player.current_answer %></p>
      <%= if @player.revealed do %>
        <.player_avatar player={@player} />
      <% end %>
    </li>
    """
  end
end
