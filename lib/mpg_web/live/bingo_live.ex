defmodule MPGWeb.BingoLive do
  use MPGWeb, :live_view
  use Phoenix.Component

  alias MPG.Bingos.Session
  alias MPG.Bingos.Player
  alias MPG.Generator
  alias Phoenix.PubSub

  import Phoenix.HTML.Form, only: [options_for_select: 2]

  @impl true
  def mount(_params, session, socket) do
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(:page_title, "Dinner Bingo")
      |> assign(:primary_color, "bg-rose-500")
      |> assign(:session_id, session_id)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => server_id}, _url, socket) do
    case Session.get_state(server_id) do
      {:ok, state} ->
        :ok = PubSub.subscribe(MPG.PubSub, server_id)

        socket =
          socket
          |> assign(:server_id, server_id)
          |> assign(:state, state)
          |> assign_player()

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Game not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # generate a random 5 digit server ID
    server_id = Enum.random(10000..99999) |> Integer.to_string()

    {:ok, _pid} =
      DynamicSupervisor.start_child(MPG.GameSupervisor, {Session, name: server_id})

    {:noreply, push_patch(socket, to: "/bingo/#{server_id}")}
  end

  defp is_host?(player, players) do
    player == List.first(players)
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
  def handle_event("select_type", %{"type" => type}, socket) do
    %{server_id: server_id} = socket.assigns
    Session.generate(server_id, String.to_existing_atom(type))
    {:noreply, push_patch(socket, to: ~p"/bingo/#{server_id}")}
  end

  @impl true
  def handle_event("toggle_cell", %{"index" => index}, socket) do
    %{session_id: session_id, server_id: server_id} = socket.assigns
    Session.toggle_cell(server_id, String.to_integer(index), session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply,
     socket
     |> assign(:state, state)
     |> assign_player()
     |> maybe_redirect_to_bingo_type_form()}
  end

  defp maybe_redirect_to_bingo_type_form(%{assigns: %{live_action: :new}} = socket), do: socket

  defp maybe_redirect_to_bingo_type_form(%{assigns: assigns} = socket) do
    %{player: player, state: state, server_id: server_id} = assigns

    if is_host?(player, state.players) && state.cells == [] do
      push_patch(socket, to: ~p"/bingo/#{server_id}/new")
    else
      socket
    end
  end

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <div class="w-full max-w-xl">
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
                <button class="bg-rose-500 hover:bg-rose-700 text-white font-bold py-2 px-4 rounded">
                  Submit
                </button>
              </div>
            </div>
          </form>
        <% else %>
          <%= if @live_action == :new && is_host?(@player, @state.players) do %>
            <!-- BINGO TYPE SELECTION -->
            <div class="pt-16">
              <h2 class="text-2xl font-bold mb-8 text-center">Choose a Bingo Type</h2>
              <form id="bingo-type-form" phx-submit="select_type">
                <div class="flex flex-col gap-4">
                  <select
                    name="type"
                    class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                  >
                    <%= options_for_select(Generator.list_bingo_types(), []) %>
                  </select>
                  <button class="bg-rose-500 hover:bg-rose-700 text-white font-bold py-2 px-4 rounded">
                    Start Game
                  </button>
                </div>
              </form>
            </div>
          <% else %>
            <!-- PLAYER LIST -->
            <div class="mb-8">
              <div id="player-list" class="flex gap-2">
                <%= for player <- @state.players do %>
                  <.player_avatar player={player} />
                <% end %>
              </div>
            </div>
            <!-- BINGO GRID -->
            <%= if @state.cells == [] do %>
              <div class="loader">Loading...</div>
            <% else %>
              <div class="grid grid-cols-5 gap-1">
                <%= for {cell, index} <- Enum.with_index(@state.cells) do %>
                  <div
                    phx-click="toggle_cell"
                    phx-value-index={index}
                    class={"relative w-full flex items-center text-center rounded cursor-pointer text-white sm:text-sm text-xs #{if cell.player_id, do: "bg-green-500", else: "bg-rose-500"}"}
                    id={"cell-#{index}"}
                  >
                    <%= cell.text %>
                    <%= if cell.player_id do %>
                      <.player_marker player={Enum.find(@state.players, &(&1.id == cell.player_id))} />
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
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

  attr :player, Player, required: true

  defp player_marker(assigns) do
    ~H"""
    <div
      class="absolute bottom-1 right-1 w-4 h-4 text-white font-bold rounded-full flex items-center justify-center text-xs"
      style={"background-color: #{@player.color}"}
    >
      <%= String.slice(@player.name, 0..1) %>
    </div>
    """
  end
end
