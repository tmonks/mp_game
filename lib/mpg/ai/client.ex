defmodule MPG.AI.Client do
  @moduledoc false

  @callback get_completion(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, map()} | {:error, map() | String.t()}
end
