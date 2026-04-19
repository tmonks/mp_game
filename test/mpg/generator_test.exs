defmodule MPG.GeneratorTest do
  use ExUnit.Case, async: true

  alias MPG.Generator
  import Mox
  import MPG.Fixtures.OpenAI

  setup :verify_on_exit!

  describe "generate_quiz_questions/1" do
    test "returns a list of questions" do
      mock_quiz_questions()

      assert questions = Generator.generate_quiz_questions("test_quiz")
      assert length(questions) == 10
      assert [%{text: "What is the first movie in the MCU?"} | _] = questions
    end
  end

  describe "generate_quiz_topics/1" do
    test "takes a starter topic and generates 5 more topics in that area" do
      expected_topics = ["banana", "apple", "orange", "grape", "kiwi"]
      mock_quiz_topics(expected_topics)

      assert Generator.generate_quiz_topics("test_topic") == expected_topics
    end
  end

  describe "generate_bingo_cells/1" do
    test "returns a list of 25 conversation prompts" do
      mock_bingo_cells()

      assert prompts = Generator.generate_bingo_cells(:conversation)
      assert length(prompts) == 25
      assert [first_prompt | _] = prompts
      assert is_binary(first_prompt)
      assert first_prompt == "Changed your opinion about something"
    end

    test "returns the first 25 if the API returns more than 25" do
      expected_prompts = Enum.map(1..30, &"Cell #{&1}")
      mock_bingo_cells(expected_prompts)

      assert prompts = Generator.generate_bingo_cells(:conversation)
      assert length(prompts) == 25
    end
  end

  describe "list_bingo_types/0" do
    test "returns a list of bingo types and their descriptions" do
      assert Generator.list_bingo_types() == [
               {"Stories about my week", :conversation},
               {"Embarrassing stories & guilty pleasures", :guilty},
               {"Unique skills, quirks, and traits", :unique}
             ]
    end
  end
end
