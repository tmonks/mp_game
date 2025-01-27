defmodule MPGWeb.HomeLiveTest do
  use MPGWeb.ConnCase
  import Phoenix.LiveViewTest

  test "includes a link to /things and /quiz", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "a#things-link")
    assert has_element?(view, "a#quiz-link")
  end

  test "redirects to Things if a Things server ID is provided", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    start_supervised!({MPG.Things.Session, [name: "12345"]})

    view
    |> form("#join-form", %{game_id: "12345"})
    |> render_submit()

    assert_redirect(view, ~p"/things/12345")
  end

  test "redirects to Quiz if a Quiz server ID is provided", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    start_supervised!({MPG.Quizzes.Session, [name: "12345"]})

    view
    |> form("#join-form", %{game_id: "12345"})
    |> render_submit()

    assert_redirect(view, ~p"/quiz/12345")
  end
end
