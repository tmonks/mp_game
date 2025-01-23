defmodule MPGWeb.HomeLiveTest do
  use MPGWeb.ConnCase
  import Phoenix.LiveViewTest

  test "includes a link to /things and /quiz", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "a#things-link")
    assert has_element?(view, "a#quiz-link")
  end

  test "can join an existing Things game", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#join-form", %{game_id: "1234"})
    |> render_submit()

    assert_redirect(view, ~p"/things/1234")
  end
end
