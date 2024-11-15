defmodule MPGWeb.QuizLive do
  use MPGWeb, :live_view

  alias MPG.Quizzes
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
      |> assign_player()

    {:ok, socket}
  end

  defp assign_player(%{assigns: assigns} = socket) do
    player = Quizzes.get_player(assigns.state, assigns.session_id)
    assign(socket, player: player)
  end

  @impl true
  def handle_event("join", %{"player_name" => player_name}, socket) do
    session_id = socket.assigns.session_id
    Session.add_player(:quiz_session, session_id, player_name)
    {:noreply, socket}
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
    <!-- JOIN FORM -->
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
    <% end %>
    <!-- PLAYER LIST -->
    <div class="mb-8">
      <div id="player-list" class="flex gap-2">
        <%= for player <- @state.players do %>
          <.player_avatar player={player} />
        <% end %>
      </div>
    </div>
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
end
