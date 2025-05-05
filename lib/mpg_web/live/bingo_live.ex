defmodule MPGWeb.BingoLive do
  use MPGWeb, :live_view
  use Phoenix.Component

  alias MPG.Bingos.Session
  alias MPG.Bingos.Player
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => server_id}, session, socket) do
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(:page_title, "Dinner Bingo")
      |> assign(:primary_color, "bg-orange-500")
      |> assign(:session_id, session_id)

    case Session.get_state(server_id) do
      {:ok, state} ->
        :ok = PubSub.subscribe(MPG.PubSub, server_id)

        {:ok,
         socket
         |> assign(:server_id, server_id)
         |> assign(:state, state)
         |> assign_player()}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def mount(_params, session, socket) do
    %{"session_id" => _session_id} = session

    # generate a random 5 digit server ID
    server_id = Enum.random(10000..99999) |> Integer.to_string()

    {:ok, _pid} =
      DynamicSupervisor.start_child(MPG.GameSupervisor, {Session, name: server_id})

    {:ok, push_navigate(socket, to: "/bingo/#{server_id}")}
  end

  defp assign_player(%{assigns: assigns} = socket) do
    player = Enum.find(assigns.state.players, &(&1.id == assigns.session_id))
    assign(socket, :player, player)
  end

  @impl true
  def handle_event("join", %{"player_name" => player_name}, socket) do
    %{session_id: session_id, server_id: server_id} = socket.assigns
    Session.add_player(server_id, session_id, player_name)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply,
     socket
     |> assign(:state, state)
     |> assign_player()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center p-4">
      <h1 class="text-2xl font-bold mb-4"><%= @page_title %></h1>
      <div class="w-full max-w-md">
        <%= if @player == nil do %>
          <!-- JOIN FORM -->
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
                <button class="bg-orange-500 hover:bg-orange-700 text-white font-bold py-2 px-4 rounded">
                  Submit
                </button>
              </div>
            </div>
          </form>
        <% else %>
          <!-- PLAYER LIST -->
          <div class="mb-8">
            <div id="player-list" class="flex gap-2">
              <%= for player <- @state.players do %>
                <.player_avatar player={player} />
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :player, Player, required: true
  attr :size, :integer, default: 12

  defp player_avatar(assigns) do
    ~H"""
    <div
      class={"relative flex items-center justify-center w-#{@size} h-#{@size} text-white font-bold rounded-full"}
      data-role="avatar"
      style={"background-color: #{@player.color}"}
      id={"player-" <> @player.id}
    >
      <%= String.slice(@player.name, 0..2) %>
    </div>
    """
  end
end
