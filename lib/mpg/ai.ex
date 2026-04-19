defmodule MPG.AI do
  @moduledoc false

  @default_client MPG.AI.OpenaiExClient

  def client do
    Application.get_env(:mpg, :ai_client, @default_client)
  end
end
