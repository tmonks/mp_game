defmodule MPGWeb.BingoLive do
  use MPGWeb, :live_view

  alias MPG.Bingos.Session
  alias MPG.Bingos.State

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dinner Bingo")
     |> assign(:primary_color, "bg-orange-500")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center p-4">
      <h1 class="text-2xl font-bold mb-4"><%= @page_title %></h1>
      <div class="w-full max-w-md">
        <p>Welcome to Bingo!</p>
      </div>
    </div>
    """
  end
end
