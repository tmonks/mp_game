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
end
