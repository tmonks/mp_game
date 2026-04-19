defmodule MPG.AI.Client do
  @moduledoc false

  @callback get_completion(String.t(), String.t(), String.t(), keyword()) ::
              {:ok, String.t()} | {:error, String.t()}
end
