defmodule MPGWeb.LikelyLive do
  use MPGWeb, :live_view
  use Phoenix.Component

  alias MPG.Likely
  alias MPG.Likely.Player
  alias MPG.Likely.Session
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(page_title: "Who's Most Likely To")
      |> assign(primary_color: "bg-amber-500")
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
      end

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    server_id = Enum.random(10000..99999) |> Integer.to_string()

    {:ok, _pid} =
      DynamicSupervisor.start_child(MPG.GameSupervisor, {Session, name: server_id})

    {:noreply, push_patch(socket, to: ~p"/likely/#{server_id}")}
  end

  defp assign_player(%{assigns: assigns} = socket) do
    player = Likely.get_player(assigns.state, assigns.session_id)
    assign(socket, player: player)
  end

  defp assign_current_status(%{assigns: assigns} = socket) do
    game_status = Likely.current_status(assigns.state)
    assign(socket, game_status: game_status)
  end

  @impl true
  def handle_event("join", %{"player_name" => player_name}, socket) do
    %{session_id: session_id, server_id: server_id} = socket.assigns
    Session.add_player(server_id, session_id, player_name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    Session.start_game(socket.assigns.server_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("cast_vote", %{"player-id" => voted_for_id}, socket) do
    Session.cast_vote(socket.assigns.server_id, socket.assigns.session_id, voted_for_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_question", _params, socket) do
    Session.next_question(socket.assigns.server_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, _action, state}, socket) do
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
              placeholder="Enter your name"
              class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
            />
          </div>
          <div>
            <button class="bg-amber-500 hover:bg-amber-700 text-white font-bold py-2 px-4 rounded">
              Submit
            </button>
          </div>
        </div>
      </form>
    <% else %>
      <!-- GAME CODE -->
      <%= if @game_status in [:new, :generating, :joining] do %>
        <div id="game-code" class="text-gray-600 text-lg mb-2">
          Game Code: <%= @server_id %>
        </div>
      <% end %>
      <!-- STATUS MESSAGE -->
      <.status_message game_status={@game_status} />
      <!-- PLAYER LIST -->
      <div class="mb-8">
        <div id="player-list" class="flex gap-2">
          <%= for player <- @state.players do %>
            <.player_avatar player={player} show_vote_status={@game_status == :voting} />
          <% end %>
        </div>
      </div>
      <!-- HOST START GAME BUTTON -->
      <%= if @player.is_host and @game_status == :new do %>
        <button
          id="start-button"
          phx-click="start_game"
          class="bg-amber-500 hover:bg-amber-700 text-white font-bold py-2 px-4 rounded"
        >
          Start Game
        </button>
      <% end %>
      <!-- HOST NEXT QUESTION / START BUTTON -->
      <%= if @player.is_host and @game_status in [:joining, :revealing] do %>
        <button
          id="next-button"
          phx-click="next_question"
          class="bg-amber-500 hover:bg-amber-700 text-white font-bold py-2 px-4 rounded"
        >
          Next Question
        </button>
      <% end %>
      <!-- VOTING -->
      <%= if @game_status in [:voting, :revealing] do %>
        <!-- QUESTION COUNTER -->
        <div id="question-counter" class="text-sm text-gray-600 mb-1">
          Question <%= @state.current_question + 1 %> of <%= length(@state.questions) %>
        </div>
        <!-- QUESTION TEXT -->
        <div id="question-text" class="text-xl mb-6">
          <%= Enum.at(@state.questions, @state.current_question).text %>
        </div>
        <%= if @game_status == :voting do %>
          <.vote_buttons player={@player} players={@state.players} />
        <% else %>
          <.vote_results state={@state} />
        <% end %>
      <% end %>
      <!-- ROASTING -->
      <%= if @game_status == :roasting do %>
        <div class="text-gray-600 text-lg">
          <div class="loader">Generating roasts...</div>
        </div>
      <% end %>
      <!-- COMPLETE -->
      <%= if @game_status == :complete do %>
        <.roast_results state={@state} />
        <%= if @player.is_host do %>
          <a
            id="play-again-button"
            href={~p"/likely"}
            class="bg-amber-500 hover:bg-amber-700 text-white font-bold py-2 px-4 rounded inline-block mt-4"
          >
            Play Again
          </a>
        <% end %>
      <% end %>
    <% end %>
    """
  end

  defp status_message(assigns) do
    ~H"""
    <div id="current-status" class="text-gray-600 text-xl mb-4">
      <%= case assigns.game_status do
        :new -> "Waiting for host to start..."
        :generating -> "Generating questions..."
        :joining -> "Ready to start!"
        _ -> nil
      end %>
    </div>
    """
  end

  attr :player, Player, required: true
  attr :players, :list, required: true

  defp vote_buttons(assigns) do
    ~H"""
    <%= if @player.current_vote == nil do %>
      <div id="vote-buttons" class="flex flex-col gap-3">
        <%= for target <- @players do %>
          <button
            id={"vote-#{target.id}"}
            phx-click="cast_vote"
            phx-value-player-id={target.id}
            class="bg-gray-200 hover:bg-gray-300 text-gray-800 py-3 px-4 rounded text-left flex items-center gap-3"
          >
            <div
              class="flex items-center justify-center w-8 h-8 text-white font-bold rounded-full text-sm"
              style={"background-color: #{target.color}"}
            >
              <%= String.slice(target.name, 0..2) %>
            </div>
            <span><%= target.name %></span>
          </button>
        <% end %>
      </div>
    <% else %>
      <div id="vote-buttons" class="flex flex-col gap-3">
        <%= for target <- @players do %>
          <div
            id={"vote-#{target.id}"}
            class={"py-3 px-4 rounded text-left flex items-center gap-3 #{if target.id == @player.current_vote, do: "bg-amber-100 border-2 border-amber-500", else: "bg-gray-100 text-gray-400"}"}
          >
            <div
              class="flex items-center justify-center w-8 h-8 text-white font-bold rounded-full text-sm"
              style={"background-color: #{target.color}"}
            >
              <%= String.slice(target.name, 0..2) %>
            </div>
            <span><%= target.name %></span>
            <%= if target.id == @player.current_vote do %>
              <span class="ml-auto text-amber-600 font-semibold">Your vote</span>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp vote_results(assigns) do
    assigns =
      assign(
        assigns,
        :ranked,
        Likely.vote_results_for_question(assigns.state, assigns.state.current_question)
      )

    ~H"""
    <div id="vote-results" class="flex flex-col gap-3">
      <%= for {{player, count}, rank} <- Enum.with_index(@ranked, 1) do %>
        <div
          id={"result-#{player.id}"}
          class={"py-3 px-4 rounded flex items-center gap-3 #{if rank == 1, do: "bg-amber-100 border-2 border-amber-400", else: "bg-gray-100"}"}
        >
          <span class={"text-lg font-bold #{if rank == 1, do: "text-amber-600", else: "text-gray-400"}"}>
            #<%= rank %>
          </span>
          <div
            class="flex items-center justify-center w-8 h-8 text-white font-bold rounded-full text-sm"
            style={"background-color: #{player.color}"}
          >
            <%= String.slice(player.name, 0..2) %>
          </div>
          <span class="font-medium"><%= player.name %></span>
          <span class="ml-auto text-gray-600 font-bold">
            <%= count %> <%= if count == 1, do: "vote", else: "votes" %>
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  defp roast_results(assigns) do
    ~H"""
    <div id="roast-results" class="flex flex-col gap-6">
      <h2 class="text-2xl font-bold text-gray-800">Summary</h2>
      <%= for player <- @state.players do %>
        <div
          id={"roast-#{player.id}"}
          class="bg-white shadow-md rounded-lg p-4 border border-gray-200"
        >
          <div class="flex items-center gap-3 mb-3">
            <div
              class="flex items-center justify-center w-10 h-10 text-white font-bold rounded-full"
              style={"background-color: #{player.color}"}
            >
              <%= String.slice(player.name, 0..2) %>
            </div>
            <h3 class="text-lg font-bold"><%= player.name %></h3>
          </div>
          <p class="text-gray-700 italic">
            "<%= Map.get(@state.roasts, player.id, "No roast generated") %>"
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  attr :player, Player, required: true
  attr :size, :integer, default: 12
  attr :show_vote_status, :boolean, default: false

  defp player_avatar(assigns) do
    ~H"""
    <div
      class={"relative flex items-center justify-center w-#{@size} h-#{@size} text-white font-bold rounded-full"}
      data-role="avatar"
      style={"background-color: #{@player.color}"}
      id={"player-" <> @player.id}
    >
      <%= String.slice(@player.name, 0..2) %>
      <%= if @player.current_vote != nil and @show_vote_status do %>
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
