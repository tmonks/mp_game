defmodule MPGWeb.HomeLive do
  use MPGWeb, :live_view

  @impl true
  def handle_event("join", %{"game_id" => game_id}, socket) do
    case Registry.lookup(MPG.GameRegistry, game_id) do
      [{_pid, :quiz}] -> {:noreply, redirect(socket, to: "/quiz/#{game_id}")}
      [{_pid, :things}] -> {:noreply, redirect(socket, to: "/things/#{game_id}")}
      _ -> {:noreply, put_flash(socket, :error, "Invalid game code")}
    end
  end

  @impl true
  def render(assigns) do
    # two cards with links to /things and /quiz
    ~H"""
    <div class="flex flex-col mt-4 gap-4 w-96 mx-auto">
      <!-- JOIN FORM -->
      <h5 class="text-slate-700 text-2xl font-semibold">
        Join a Game
      </h5>
      <form id="join-form" phx-submit="join" phx-page-loading>
        <div class="relative flex gap-4">
          <input
            id="game_id"
            name="game_id"
            type="text"
            class="w-full border border-slate-200 rounded-lg p-2"
            placeholder="12345"
          />
          <button type="submit" class="bg-blue-500 text-white font-semibold rounded-lg p-2 w-24">
            Join
          </button>
        </div>
      </form>
      <!-- HOST A GAME HEADING -->
      <h5 class="mb-2 text-slate-700 text-2xl font-semibold mt-6">
        Host a Game
      </h5>
      <!-- THINGS LINK -->
      <a id="things-link" href="/things">
        <div class="relative flex flex-col bg-white shadow-sm border border-slate-200 rounded-lg">
          <div class="p-4">
            <h5 class="mb-2 text-blue-400 text-xl font-semibold">
              The Things Game
            </h5>
            <p class="text-slate-600 leading-normal font-light">
              Guess who said what in a party game where players write funny responses to prompts.
            </p>
          </div>
        </div>
      </a>
      <!-- QUIZ LINK -->
      <a id="quiz-link" href="/quiz">
        <div class="relative flex flex-col bg-white shadow-sm border border-slate-200 rounded-lg">
          <div class="p-4">
            <h5 class="mb-2 text-blue-400 text-xl font-semibold">
              Quizoots
            </h5>
            <p class="text-slate-600 leading-normal font-light">
              Try to outsmart your friends in an AI-generated quiz on whatever topic you choose.
            </p>
          </div>
        </div>
      </a>
    </div>
    """
  end
end
