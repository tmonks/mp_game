defmodule MPGWeb.QuizLive do
  use MPGWeb, :live_view

  # alias MPG.Quizzes
  alias Phoenix.PubSub

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      :ok = PubSub.subscribe(MPG.PubSub, "quiz_session")
    end

    %{"session_id" => session_id} = session

    socket =
      socket
      |> assign(session_id: session_id)
      |> assign_player()

    {:ok, socket}
  end

  defp assign_player(%{assigns: _assigns} = socket) do
    # case Things.get_player(assigns.state, assigns.session_id) do
    #   nil -> assign(socket, player: nil)
    #   player -> assign(socket, player: player)
    # end
    assign(socket, player: nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
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
    """
  end
end
