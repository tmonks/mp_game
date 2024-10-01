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
            <.link
              id="new-question-button"
              class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded mt-6"
              patch={~p"/new_question"}
            >
              New Question
            </.link>
          </div>
        <% end %>
      </div>

      <.modal
        :if={@live_action == :new_question}
        id="new-question-modal"
        show={true}
        on_cancel={JS.patch("/")}
      >
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
                <li id={"player-" <> player.id} class="flex items-center py-4 px-6">
                  <img
                    class="w-12 h-12 rounded-full object-cover mr-4"
                    src="https://randomuser.me/api/portraits/women/72.jpg"
                    alt="User avatar"
                  />
                  <div class="flex-1">
                    <h3 class="text-lg font-medium text-gray-800" data-role="player-name">
                      <%= if player.id == @player.id, do: "Me", else: player.name %>
                    </h3>
                    <p data-role="answer" class="text-gray-600 text-base">
                      <%= get_current_answer(player) %>
                    </p>
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
              <%= if Things.all_players_answered?(@state) do %>
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
      <div class="flex">
        <%= if @player.current_answer do %>
          <div class="flex flex-col p-4 gap-6 flex-1">
            <div>
              <div class="block text-gray-700 font-bold mb-2">
                My answer
              </div>
              <div id="my-answer" class="text-gray-600 text-base"><%= @player.current_answer %></div>
            </div>
            <%= if Things.all_players_answered?(@state) and !is_nil(@player) and !@player.revealed do %>
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
          <form id="answer-form" phx-submit="submit_answer" class="flex-1">
            <div class="flex flex-col gap-4">
              <div>
                <label class="block text-gray-700 font-bold mb-2" for="answer">
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
        <div class="flex-1"></div>
      </div>
    <% end %>
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
