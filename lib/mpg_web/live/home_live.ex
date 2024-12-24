defmodule MPGWeb.HomeLive do
  use MPGWeb, :live_view

  @impl true
  def render(assigns) do
    # two cards with links to /things and /quiz
    ~H"""
    <div class="grid gap-4 mt-24">
      <a id="things-link" href="/things">
        <div class="relative flex flex-col bg-white shadow-sm border border-slate-200 rounded-lg w-80">
          <div class="p-4">
            <h5 class="mb-2 text-slate-800 text-xl font-semibold">
              The Things Game
            </h5>
            <p class="text-slate-600 leading-normal font-light">
              Guess who said what in this party game where players write funny responses to prompts.
            </p>
          </div>
        </div>
      </a>
      <a id="quiz-link" href="/quiz">
        <div class="relative flex flex-col bg-white shadow-sm border border-slate-200 rounded-lg w-80">
          <div class="p-4">
            <h5 class="mb-2 text-slate-800 text-xl font-semibold">
              Quizoots
            </h5>
            <p class="text-slate-600 leading-normal font-light">
              Try to outsmart your friends in a competitive quiz game in whatever topic you choose.
            </p>
          </div>
        </div>
      </a>
    </div>
    """
  end
end
