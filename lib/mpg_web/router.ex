defmodule MPGWeb.Router do
  use MPGWeb, :router

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

  scope "/", MPGWeb do
    pipe_through :browser

    live "/", ThingsLive, :play
    live "/new_question", ThingsLive, :new_question

    live "/quiz", QuizLive, :play
  end

  defp assign_session_id(conn, _opts) do
    case get_session(conn, :session_id) do
      nil -> put_session(conn, :session_id, UUID.uuid4())
      _ -> conn
    end
  end
end
