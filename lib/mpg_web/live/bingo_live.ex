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
      |> assign(:page_title, "Conversation Bingo")
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

  defp bingo_type_label(nil), do: nil

  defp bingo_type_label(type) do
    type_atom = String.to_existing_atom(type)

    Generator.list_bingo_types()
    |> Enum.find(fn {_label, t} -> t == type_atom end)
    |> case do
      {label, _} -> label
      nil -> type
    end
  end

  defp marked_count(cells) do
    Enum.count(cells, &(&1.player_id != nil))
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
  def handle_event("new_game", _params, socket) do
    Session.reset_cells(socket.assigns.server_id)
    {:noreply, socket}
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
    <div class="min-h-screen text-white">
      <%= if @player == nil do %>
        <!-- JOIN FORM -->
        <div class="flex items-center justify-center pt-24 px-4">
          <form id="join-form" phx-submit="join" class="w-full max-w-sm">
            <h2 class="text-purple-400 font-bold text-xl mb-6 text-center">Join the Game</h2>
            <input
              type="text"
              name="player_name"
              placeholder="Enter your name"
              class="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-purple-500 mb-4"
            />
            <button class="w-full bg-purple-700 hover:bg-purple-600 text-white font-bold py-3 px-4 rounded-xl transition-colors">
              Join
            </button>
          </form>
        </div>
      <% else %>
        <%= if @live_action == :new && is_host?(@player, @state.players) do %>
          <!-- BINGO TYPE SELECTION -->
          <div class="flex items-center justify-center pt-24 px-4">
            <div class="w-full max-w-sm">
              <h2 class="text-purple-400 font-bold text-xl mb-6 text-center">Choose a Bingo Type</h2>
              <form id="bingo-type-form" phx-submit="select_type">
                <select
                  name="type"
                  class="w-full bg-slate-800 border border-slate-700 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-purple-500 mb-4"
                >
                  {options_for_select(Generator.list_bingo_types(), [])}
                </select>
                <button class="w-full bg-purple-700 hover:bg-purple-600 text-white font-bold py-3 px-4 rounded-xl transition-colors">
                  Start Game
                </button>
              </form>
            </div>
          </div>
        <% else %>
          <!-- GAME VIEW -->
          <!-- Header -->
          <div class="p-4 pb-2 flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
            <h2 class="text-purple-400 font-bold text-xl tracking-tight whitespace-nowrap">
              Conversation Bingo
            </h2>
            <%= if @state.bingo_type do %>
              <span
                id="bingo-type-label"
                class="px-3 py-1 text-xs font-semibold bg-slate-800 border border-slate-700 text-purple-400 rounded-full"
              >
                {bingo_type_label(@state.bingo_type)}
              </span>
            <% end %>
          </div>
          <!-- Players -->
          <div class="px-4 pb-3">
            <div class="text-xs text-slate-500 uppercase tracking-wider font-semibold mb-2">
              Players — {length(@state.players)} joined
            </div>
            <div class="flex gap-2 overflow-x-auto hide-scrollbar p-1">
              <%= for player <- @state.players do %>
                <.player_avatar player={player} current={player.id == @player.id} />
              <% end %>
            </div>
          </div>
          <!-- Progress -->
          <div class="px-4 pb-3">
            <div class="flex justify-between text-sm mb-1.5">
              <span class="text-slate-400">Completed</span>
              <span class="text-purple-400 font-bold">{marked_count(@state.cells)} / 25</span>
            </div>
            <div class="h-1.5 bg-slate-800 rounded-full overflow-hidden">
              <div
                class="h-full bg-purple-600 rounded-full transition-all duration-500"
                style={"width: #{marked_count(@state.cells) / 25 * 100}%"}
              >
              </div>
            </div>
          </div>
          <!-- Bingo Grid -->
          <%= if @state.cells == [] do %>
            <div class="loader">Loading...</div>
          <% else %>
            <div class="px-3 pb-8">
              <div class="grid grid-cols-5 gap-1.5">
                <%= for {cell, index} <- Enum.with_index(@state.cells) do %>
                  <div
                    phx-click="toggle_cell"
                    phx-value-index={index}
                    class={"relative flex items-center justify-center text-center rounded-xl cursor-pointer font-medium leading-tight aspect-[1/1.1] p-1 border transition-colors #{if cell.player_id, do: "bg-purple-900 border-purple-500 text-white", else: "bg-slate-800 border-slate-700 text-slate-300 hover:bg-slate-700 hover:border-slate-600"} sm:text-xs text-[10px]"}
                    id={"cell-#{index}"}
                  >
                    {cell.text}
                    <%= if cell.player_id do %>
                      <.player_marker player={Enum.find(@state.players, &(&1.id == cell.player_id))} />
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
            <%= if is_host?(@player, @state.players) do %>
              <div class="px-3 pb-4">
                <button
                  id="new-game-btn"
                  phx-click="new_game"
                  class="bg-purple-700 hover:bg-purple-600 text-white text-sm font-bold py-2 px-4 rounded-xl transition-colors"
                >
                  New Game
                </button>
              </div>
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :player, Player, required: true
  attr :current, :boolean, default: false

  defp player_avatar(assigns) do
    ~H"""
    <div
      class={"flex items-center justify-center w-10 h-10 text-xs text-white font-bold rounded-full flex-shrink-0 #{if @current, do: "ring-2 ring-purple-500"}"}
      data-role="avatar"
      style={"background-color: #{@player.color}"}
      id={"player-" <> @player.id}
    >
      {String.slice(@player.name, 0..2)}
    </div>
    """
  end

  attr :player, Player, required: true

  defp player_marker(assigns) do
    ~H"""
    <div
      class="absolute bottom-1 right-1 w-4 h-4 text-white font-bold rounded-full flex items-center justify-center text-[7px] shadow-[0_0_0_1.5px_theme(colors.slate.900)]"
      style={"background-color: #{@player.color}"}
    >
      {String.slice(@player.name, 0..1)}
    </div>
    """
  end
end
