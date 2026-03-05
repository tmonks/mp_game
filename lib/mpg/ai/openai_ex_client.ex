defmodule MPG.AI.OpenaiExClient do
  @moduledoc false

  @behaviour MPG.AI.Client

  @impl true
  def get_completion(_model, _system_prompt, _user_prompt, _options \\ []) do
    {:error, "OpenaiEx client is not wired yet"}
  end
end
