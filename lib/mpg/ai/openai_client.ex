defmodule MPG.AI.OpenAIClient do
  @moduledoc false

  @behaviour MPG.AI.Client

  @impl true
  def get_completion(model, system_prompt, user_prompt, options \\ []) do
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]

    args = Keyword.merge([model: model, messages: messages], options)

    OpenAI.chat_completion(args)
  end
end
