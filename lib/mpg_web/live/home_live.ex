defmodule MPGWeb.HomeLive do
  use MPGWeb, :live_view

  @impl true
  def render(assigns) do
    # two cards with links to /things and /quiz
    ~H"""
    <div class="grid grid-cols-2 gap-4 mt-24">
      <a
        id="things-link"
        href="/things"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Game of Things
      </a>
      <a
        id="quiz-link"
        href="/quiz"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Multi-Player Quiz
      </a>
    </div>
    """
  end
end
