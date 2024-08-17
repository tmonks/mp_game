defmodule MPGWeb.Router do
  use MPGWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MPGWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MPGWeb do
    pipe_through :browser

    live "/", ThingsLive, :play
  end

  # Other scopes may use custom stacks.
  # scope "/api", MPGWeb do
  #   pipe_through :api
  # end
end
