defmodule MPG.AI.OpenaiExClient do
  @moduledoc false

  @behaviour MPG.AI.Client

  @impl true
  # REVIEW: add doc here, especially explaining options
  def get_completion(model, system_prompt, user_prompt, options \\ []) do
    api_key = Application.fetch_env!(:openai_ex, :api_key)
    client = OpenaiEx.new(api_key)

    params =
      %{
        model: map_model(model),
        instructions: system_prompt,
        input: user_prompt
      }
      |> maybe_put(:temperature, Keyword.get(options, :temperature))
      |> maybe_add_text_format(options)
      |> maybe_add_web_search(model)

    case OpenaiEx.Responses.create(client, params) do
      {:ok, %{"output" => output}} ->
        {:ok, extract_text(output)}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp extract_text(output) do
    output
    |> Enum.find_value(fn
      %{"type" => "message", "content" => content} ->
        Enum.find_value(content, fn
          %{"type" => "output_text", "text" => text} -> text
          _ -> nil
        end)

      _ ->
        nil
    end)
  end

  defp map_model("gpt-4o-mini-search-preview"), do: "gpt-4o-mini"
  defp map_model(model), do: model

  defp maybe_add_text_format(params, options) do
    case Keyword.get(options, :response_format) do
      %{type: "json_object"} ->
        # The Responses API requires the word "json" to appear in the input field
        # (not just instructions) when using json_object format.
        input = params.input

        input =
          if String.match?(input, ~r/json/i), do: input, else: input <> " (Respond with JSON)"

        params
        |> Map.put(:input, input)
        |> Map.put(:text, %{format: %{type: "json_object"}})

      _ ->
        params
    end
  end

  defp maybe_add_web_search(params, "gpt-4o-mini-search-preview") do
    Map.put(params, :tools, [%{type: "web_search_preview"}])
  end

  defp maybe_add_web_search(params, _model), do: params

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
