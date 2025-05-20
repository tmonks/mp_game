defmodule MPG.GeneratorTest do
  use ExUnit.Case, async: false

  alias MPG.Generator
  import MPG.Fixtures.OpenAI

  setup do
    bypass = Bypass.open(port: 4010)
    {:ok, bypass: bypass}
  end

  describe "generate_quiz_questions/1" do
    test "returns a list of questions", ctx do
      Bypass.expect_once(ctx.bypass, "POST", "/v1/chat/completions", fn conn ->
        Plug.Conn.resp(conn, 200, chat_response_quiz_questions())
      end)

      assert questions = Generator.generate_quiz_questions("test_quiz")
      assert length(questions) == 10
      assert [%{text: "What is the first movie in the MCU?"} | _] = questions
    end
  end

  describe "generate_quiz_topics/1" do
    test "takes a starter topic and generates 5 more topics in that area", ctx do
      expected_topics = ["banana", "apple", "orange", "grape", "kiwi"]

      Bypass.expect_once(ctx.bypass, "POST", "/v1/chat/completions", fn conn ->
        Plug.Conn.resp(conn, 200, chat_response_quiz_topics(expected_topics))
      end)

      assert Generator.generate_quiz_topics("test_topic") == expected_topics
    end
  end

  describe "generate_bingo_cells/1" do
    test "returns a list of 25 conversation prompts", ctx do
      Bypass.expect_once(ctx.bypass, "POST", "/v1/chat/completions", fn conn ->
        Plug.Conn.resp(conn, 200, chat_response_bingo_cells())
      end)

      assert prompts = Generator.generate_bingo_cells("conversation")
      assert length(prompts) == 25
      assert [first_prompt | _] = prompts
      assert is_binary(first_prompt)
      assert first_prompt == "Changed your opinion about something"
    end

    test "returns the first 25 if the API returns more than 25", ctx do
      expected_prompts = Enum.map(1..30, &"Cell #{&1}")

      Bypass.expect_once(ctx.bypass, "POST", "/v1/chat/completions", fn conn ->
        Plug.Conn.resp(conn, 200, chat_response_bingo_cells(expected_prompts))
      end)

      assert prompts = Generator.generate_bingo_cells("conversation")
      assert length(prompts) == 25
    end
  end
end
