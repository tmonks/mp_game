defmodule MPGWeb.BingoLiveTest do
  use MPGWeb.ConnCase

  import Phoenix.LiveViewTest
  alias MPG.Bingos.Session
  alias MPG.Bingos.State

  setup do
    server_id = "test_server"
    start_supervised!({Session, [name: server_id]})
    %{server_id: server_id}
  end

  test "visiting /bingo redirects to a random server ID", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path}}} = live(conn, ~p"/bingo")

    assert new_path =~ ~r"/bingo/[0-9]{5}"

    # retrieve the server name from the `name` URL param
    server_id = new_path |> String.split("/") |> List.last()

    # Session GenServer started with that name
    assert {:ok, %State{server_id: ^server_id}} = Session.get_state(server_id)
  end

  test "redirects to home page if the server ID is invalid", %{conn: conn} do
    conn = get(conn, "/bingo/invalid_id")
    assert redirected_to(conn) == "/"
  end

  test "can access bingo page with valid server ID", %{conn: conn, server_id: server_id} do
    {:ok, _view, html} = live(conn, "/bingo/#{server_id}")
    assert html =~ "Dinner Bingo"
    assert html =~ server_id
  end
end
