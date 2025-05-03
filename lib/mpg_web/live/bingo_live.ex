defmodule MPGWeb.BingoLive do
  use MPGWeb, :live_view

  alias MPG.Bingos.Session

  @impl true
  def mount(%{"id" => server_id}, _session, socket) do
    case Session.get_state(server_id) do
      {:ok, state} ->
        {:ok,
         socket
         |> assign(:page_title, "Dinner Bingo")
         |> assign(:primary_color, "bg-orange-500")
         |> assign(:server_id, server_id)
         |> assign(:state, state)}

      {:error, :not_found} ->
        {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    # generate a random 5 digit server ID
    server_id = Enum.random(10000..99999) |> Integer.to_string()

    {:ok, _pid} =
      DynamicSupervisor.start_child(MPG.GameSupervisor, {Session, name: server_id})

    {:ok, push_navigate(socket, to: "/bingo/#{server_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center p-4">
      <h1 class="text-2xl font-bold mb-4"><%= @page_title %></h1>
      <div class="w-full max-w-md">
        <p>Welcome to Bingo!</p>
        <p>Server ID: <%= @server_id %></p>
      </div>
    </div>
    """
  end
end
