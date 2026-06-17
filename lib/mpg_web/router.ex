defmodule MPGWeb.Router do
  use MPGWeb, :router
  use PhoenixAnalytics.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MPGWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :assign_session_id
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :dark_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MPGWeb.Layouts, :dark_root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :assign_session_id
  end

  scope "/", MPGWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/join", JoinLive, :index

    live "/things", ThingsLive, :new
    live "/things/:id", ThingsLive, :play
    live "/things/:id/new_question", ThingsLive, :new_question
    live "/things/:id/reveal", ThingsLive, :reveal

    live "/quiz", QuizLive, :new
    live "/quiz/:id", QuizLive, :play
    live "/quiz/:id/new_quiz", QuizLive, :new_quiz
    live "/quiz/:id/new", QuizLive.New, :new

    live "/likely", LikelyLive, :new
    live "/likely/:id", LikelyLive, :play
  end

  scope "/", MPGWeb do
    pipe_through :dark_browser

    live "/bingo", BingoLive, :new
    live "/bingo/:id", BingoLive, :play
    live "/bingo/:id/new", BingoLive, :new
  end

  pipeline :analytics_auth do
    plug :analytics_basic_auth
  end

  scope "/" do
    pipe_through :analytics_auth
    phoenix_analytics_dashboard("/analytics")
  end

  defp analytics_basic_auth(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn,
      username: Application.get_env(:mpg, :analytics_username, "admin"),
      password: Application.get_env(:mpg, :analytics_password, "secret")
    )
  end

  defp assign_session_id(conn, _opts) do
    case get_session(conn, :session_id) do
      nil -> put_session(conn, :session_id, UUID.uuid4())
      _ -> conn
    end
  end
end
