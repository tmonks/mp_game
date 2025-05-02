defmodule MPGWeb.BingoLiveTest do
  use MPGWeb.ConnCase

  import Phoenix.LiveViewTest

  test "visiting /bingo shows the bingo page", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/bingo")
    assert html =~ "Dinner Bingo"
  end
end
