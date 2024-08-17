defmodule MPGWeb.ThingsLive do
  use MPGWeb, :live_view

  alias MPG.Things.Session

  @impl true
  def mount(_params, _session, socket) do
    state = Session.get_state(:things_session)
    {:ok, assign(socket, state: state)}
  end

  @impl true
  def handle_event("join", %{"player_name" => player_name}, socket) do
    Session.add_player(:things_session, player_name)
    state = Session.get_state(:things_session)
    {:noreply, assign(socket, state: state, player_name: player_name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Game of Things</h1>
    <br />
    <h2>Players</h2>
    <%= for player <- @state.players do %>
      <span><%= player.name %></span>
    <% end %>

    <%= if assigns[:player_name] do %>
      <h2>Waiting for question...</h2>
    <% else %>
      <form phx-submit="join">
        <div>
          <input type="text" name="player_name" />
        </div>
        <div>
          <button class="button">Join</button>
        </div>
      </form>
    <% end %>
    """
  end
end
