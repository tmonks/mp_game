defmodule MPG.Release do
  @app :mpg

  def migrate do
    Application.load(@app)
    {:ok, _, _} = Ecto.Migrator.with_repo(MPG.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  end
end
