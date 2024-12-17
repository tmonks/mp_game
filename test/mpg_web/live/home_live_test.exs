defmodule MPGWeb.HomeLiveTest do
  use MPGWeb.ConnCase
  import Phoenix.LiveViewTest

  test "includes a link to /things and /quiz", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "a#things-link")
    assert has_element?(view, "a#quiz-link")
  end
end
