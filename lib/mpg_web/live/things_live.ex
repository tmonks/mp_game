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

    # hide the modal
    socket = push_event(socket, "js-exec", %{to: "#new-question-modal", attr: "phx-remove"})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply, assign(socket, state: state) |> assign_player()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1 class="text-3xl font-semibold text-gray-800">Game of Things</h1>
    <br />

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
      <div class="flex justify-between items-center">
        <h2 id="current-question" class="text-xl text-gray-600"><%= @state.topic %>...</h2>

        <%= if @player.is_host do %>
          <div>
            <button
              id="new-question-button"
              class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded mt-6"
              phx-click={show_modal("new-question-modal")}
            >
              New Question
            </button>
          </div>
        <% end %>
      </div>

      <.modal id="new-question-modal">
        <div class="font-bold mb-4">New Question</div>
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

      <div class="flex my-6 gap-8">
        <div class="flex-1">
          <div class="bg-white shadow-md rounded-md overflow-hidden max-w-lg mx-auto">
            <div class="bg-gray-100 py-2 px-4">
              <h2 class="text-xl font-semibold text-gray-800">Players</h2>
            </div>
            <ul class="divide-y divide-gray-200">
              <%= for player <- @state.players do %>
                <li class="flex items-center py-4 px-6">
                  <img
                    class="w-12 h-12 rounded-full object-cover mr-4"
                    src="https://randomuser.me/api/portraits/women/72.jpg"
                    alt="User avatar"
                  />
                  <div class="flex-1">
                    <h3 class="text-lg font-medium text-gray-800"><%= player.name %></h3>
                    <p class="text-gray-600 text-base"><%= get_current_answer(player) %></p>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
        <div class="flex-1">
          <div class="bg-white shadow-md rounded-md overflow-hidden max-w-lg mx-auto">
            <div class="bg-gray-100 py-2 px-4">
              <h2 class="text-xl font-semibold text-gray-800">Answers</h2>
            </div>
            <ul class="divide-y divide-gray-200">
              <%= if Game.all_players_answered?(:things_session) do %>
                <div id="unrevealed-answers">
                  <%= for answer <- unrevealed_answers(@state.players) do %>
                    <li class="flex items-center py-4 px-6">
                      <p class="text-gray-600 text-base"><%= answer %></p>
                    </li>
                  <% end %>
                </div>
              <% end %>
            </ul>
          </div>
        </div>
      </div>

      <br />
      <%= if @player.current_answer do %>
        <div class="flex p-4 items-center gap-4">
          <div id="my-answer" class="text-gray-600 text-base"><%= @player.current_answer %></div>
          <%= if Game.all_players_answered?(:things_session) and !is_nil(@player) and !@player.revealed do %>
            <button
              id="reveal-button"
              class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
              phx-click="reveal"
            >
              Reveal
            </button>
          <% end %>
        </div>
      <% else %>
        <form id="answer-form" phx-submit="submit_answer">
          <div class="flex justify-between items-center gap-4">
            <input
              type="text"
              name="answer"
              placeholder="My answer"
              class="flex-1 shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
            <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
              Submit
            </button>
          </div>
        </form>
      <% end %>
    <% end %>
    """
  end

  defp player_row(assigns) do
    ~H"""
    <div id={"player-" <> @player.id}>
      <span data-role="player-name"><%= @player.name %></span>
      <span data-role="answer">
        <%= get_current_answer(@player) %>
      </span>
    </div>
    """
  end

  defp current_player_row(assigns) do
    ~H"""
    <div id={"player-" <> @player.id}>
      <span data-role="player-name">Me</span>
      <span data-role="answer"><%= get_current_answer(@player) %></span>
    </div>
    """
  end

  defp get_current_answer(player) do
    cond do
      player.revealed -> player.current_answer
      player.current_answer -> "Ready"
      true -> "No answer yet"
    end
  end

  defp unrevealed_answers(players) do
    players
    |> Enum.filter(&(!&1.revealed))
    |> Enum.map(& &1.current_answer)
    |> Enum.shuffle()
  end
end
