defmodule MPGWeb.ThingsLive do
  use MPGWeb, :live_view

  alias MPG.Things
  alias MPG.Things.Session

  @impl true
  def mount(_params, session, socket) do
    state = Session.get_state(:things_session)
    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(session_id: session_id)
      |> assign(state: state)
      |> maybe_assign_player()

    {:ok, socket}
  end

  defp maybe_assign_player(%{assigns: assigns} = socket) do
    case Things.get_player(assigns.state, assigns.session_id) do
      nil -> socket
      player -> assign(socket, player_name: player.name)
    end
  end

  @impl true
  def handle_event("join", %{"player_name" => player_name}, socket) do
    Session.add_player(:things_session, socket.assigns.session_id, player_name)
    state = Session.get_state(:things_session)
    {:noreply, assign(socket, state: state, player_name: player_name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Game of Things</h1>
    <br />

    <%= unless assigns[:player_name] do %>
      <form id="join-form" phx-submit="join">
        <div>
          <input type="text" name="player_name" />
        </div>
        <div>
          <button class="button">Join</button>
        </div>
      </form>
    <% end %>

    <br />
    <h2>Players</h2>
    <%= for player <- @state.players do %>
      <%= if player.id == @session_id do %>
        <.current_player_row player={player} />
      <% else %>
        <.player_row player={player} />
      <% end %>
    <% end %>
    """
  end

  defp player_row(assigns) do
    ~H"""
    <div id={"player-" <> @player.id}>
      <span data-role="player-name"><%= @player.name %></span>
      <span data-role="answer">
        <%= if @player.current_answer, do: "Ready", else: "No answer yet" %>
      </span>
    </div>
    """
  end

  defp current_player_row(assigns) do
    ~H"""
    <div id={"player-" <> @player.id}>
      <span data-role="player-name">Me</span>
      <span data-role="answer">
        <%= @player.current_answer || "No answer yet" %>
      </span>
    </div>
    """
  end
end
