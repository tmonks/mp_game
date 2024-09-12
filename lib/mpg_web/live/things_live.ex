defmodule MPGWeb.ThingsLive do
  use MPGWeb, :live_view

  alias MPG.Things
  alias MPG.Things.Session
  alias Phoenix.PubSub

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
    Session.add_player(:things_session, session_id, player_name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_answer", %{"answer" => answer}, socket) do
    Session.set_player_answer(:things_session, socket.assigns.session_id, answer)
    {:noreply, socket}
  end

  @impl true
  def handle_event("reveal", _, socket) do
    Session.set_player_to_revealed(:things_session, socket.assigns.session_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply, assign(socket, state: state) |> assign_player()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1 class="text-lg">Game of Things</h1>
    <br />

    <h2 class="font-bold">Current Question</h2>
    <div id="current-question"><%= @state.topic %></div>
    <br />

    <%= unless assigns[:player] do %>
      <form id="join-form" phx-submit="join">
        <div>
          <input type="text" name="player_name" />
        </div>
        <div>
          <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
            Join
          </button>
        </div>
      </form>
    <% else %>
      <div class="flex mb-6">
        <div class="flex-1">
          <h2 class="font-bold">Players</h2>
          <%= for player <- @state.players do %>
            <%= if player.id == @session_id do %>
              <.current_player_row player={player} />
            <% else %>
              <.player_row player={player} />
            <% end %>
          <% end %>
        </div>
        <div class="flex-1">
          <h2 class="font-bold">Answers</h2>
          <%= if Session.all_players_answered?(:things_session) do %>
            <div id="unrevealed-answers">
              <%= for answer <- unrevealed_answers(@state.players) do %>
                <div><%= answer %></div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <br />
      <div class="font-bold">My answer</div>
      <%= if @player.current_answer do %>
        <div id="my-answer"><%= @player.current_answer %></div>
      <% else %>
        <form id="answer-form" phx-submit="submit_answer">
          <div class="flex">
            <input type="text" name="answer" />
            <button class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
              Submit
            </button>
          </div>
        </form>
      <% end %>

      <%= if Session.all_players_answered?(:things_session) and !is_nil(@player) and !@player.revealed do %>
        <button id="reveal-button" phx-click="reveal">Reveal</button>
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
