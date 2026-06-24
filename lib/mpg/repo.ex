defmodule MPG.Repo do
  use Ecto.Repo,
    otp_app: :mpg,
    adapter: Ecto.Adapters.SQLite3
end
