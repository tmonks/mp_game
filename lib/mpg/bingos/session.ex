defmodule MPG.Bingos.Session do
  use GenServer

  alias MPG.Bingos
  alias MPG.Generator
  alias Phoenix.PubSub

  def child_spec(opts) do
    name = Keyword.get(opts, :name, "bingos")

    %{
      id: "#{__MODULE__}_#{name}",
      start: {__MODULE__, :start_link, [name]}
    }
  end

  @doc """
  Starts the server.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: registered_name(name))
  end

  @doc """
  Pings the server.
  """
  def ping(server_id) do
    registered_name(server_id)
    |> GenServer.call(:ping)
  end

  @doc """
  Retrieves the state.
  Returns {:ok, state} if the server is found, otherwise {:error, :not_found}.
  """
  def get_state(server_id) do
    case Registry.lookup(MPG.GameRegistry, server_id) do
      [{_, _pid}] -> {:ok, registered_name(server_id) |> GenServer.call(:get_state)}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Updates the cells in the state.
  """
  def update_cells(server_id, cells) do
    registered_name(server_id)
    |> GenServer.cast({:update_cells, cells})
  end

  @doc """
  Adds a player to the state.
  """
  def add_player(server_id, player_id, player_name) do
    registered_name(server_id)
    |> GenServer.cast({:add_player, player_id, player_name})
  end

  @doc """
  Toggles a cell for a player.
  """
  def toggle_cell(server_id, cell_index, player_id) do
    registered_name(server_id)
    |> GenServer.cast({:toggle_cell, cell_index, player_id})
  end

  @doc """
  Generates new bingo cells asynchronously for the given type.
  """
  def generate(server_id, type) do
    registered_name(server_id)
    |> GenServer.cast({:generate, type})
  end

  @doc """
  Determines the Registry name ("via tuple") from a string id
  """
  def registered_name(id) do
    {:via, Registry, {MPG.GameRegistry, id, :bingo}}
  end

  @impl true
  def init(server_id) do
    state = Bingos.new(server_id)
    {:ok, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_cells, cells}, state) do
    state = Bingos.update_cells(state, cells)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_player, id, player_name}, state) do
    state = Bingos.add_player(state, id, player_name)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:toggle_cell, cell_index, player_id}, state) do
    state = Bingos.toggle(state, cell_index, player_id)
    broadcast_state_updated(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:generate, type}, state) do
    server = registered_name(state.server_id)
    # start a background task to generate the bingo cells
    Task.start(fn ->
      cells = Generator.generate_bingo_cells(type)
      GenServer.cast(server, {:update_cells, cells})
    end)

    {:noreply, state}
  end

  defp broadcast_state_updated(state) do
    PubSub.broadcast(MPG.PubSub, state.server_id, {:state_updated, state})
  end
end
