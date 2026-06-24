defmodule MPGWeb.Plugs.AnalyticsTracker do
  @moduledoc """
  Wraps `PhoenixAnalytics.Plugs.RequestTracker` so the analytics dashboard
  shows useful "Top Pages" data:

    * the `/analytics` dashboard itself is never tracked
    * per-game paths like `/quiz/98019` are grouped down to `/quiz`, so visits
      are counted per game rather than per random game ID
  """

  @behaviour Plug

  alias PhoenixAnalytics.Plugs.RequestTracker

  @impl true
  def init(opts), do: RequestTracker.init(opts)

  @impl true
  def call(conn, opts) do
    if track?(conn.request_path) do
      track(conn, opts)
    else
      conn
    end
  end

  defp track?("/analytics" <> _), do: false
  defp track?(_), do: true

  # RequestTracker reads `conn.request_path` from inside a `before_send`
  # callback. `before_send` callbacks run last-registered-first, so by
  # registering ours *after* RequestTracker's, `normalize_path/1` runs first
  # and rewrites the path just before the tracker records it.
  defp track(conn, opts) do
    conn
    |> RequestTracker.call(opts)
    |> Plug.Conn.register_before_send(&normalize_path/1)
  end

  defp normalize_path(conn) do
    %{conn | request_path: group_path(conn.request_path)}
  end

  # "/quiz/98019" -> "/quiz", "/" stays "/"
  defp group_path(path) do
    case String.split(path, "/", trim: true) do
      [game | _] -> "/" <> game
      [] -> "/"
    end
  end
end
