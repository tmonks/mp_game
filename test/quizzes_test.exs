defmodule MPG.QuizzesTest do
  use ExUnit.Case

  alias MPG.Quizzes
  alias MPG.Quizzes.Player
  alias MPG.Quizzes.Question
  alias MPG.Quizzes.State

  describe "set_title/2" do
    test "sets the title of the quiz" do
      state = %State{}

      assert %State{title: "Marvel characters"} = Quizzes.set_title(state, "Marvel characters")
    end
  end

  describe "set_questions/2" do
    test "sets the questions of the quiz" do
      state = %State{}

      questions = [
        %{
          text: "Who is the fastest Avenger?",
          answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
          correct_answer: 1,
          explanation: "Thor is the fastest Avenger."
        }
      ]

      assert %State{questions: [%Question{} = question]} = Quizzes.set_questions(state, questions)

      assert question.text == "Who is the fastest Avenger?"
      assert question.answers == ["Hulk", "Thor", "Iron Man", "Captain America"]
      assert question.correct_answer == 1
      assert question.explanation == "Thor is the fastest Avenger."
    end
  end

  describe "start_quiz/2" do
    test "sets the current_question to 0" do
      state = %State{}

      assert state.current_question == nil
      assert %State{current_question: 0} = Quizzes.start_quiz(state)
    end
  end

  describe "create_quiz/1" do
    test "creates a new state with valid attributes" do
      attrs = %{
        title: "Marvel characters",
        questions: [
          %{
            text: "Who is the strongest Avenger?",
            answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
            correct_answer: 0,
            explanation: "Hulk is the strongest Avenger."
          }
        ]
      }

      assert %State{} = state = Quizzes.create_quiz(attrs)

      assert state.title == "Marvel characters"
      assert state.current_question == 0
      assert [%Question{} = question] = state.questions
      assert question.text == "Who is the strongest Avenger?"
      assert question.answers == ["Hulk", "Thor", "Iron Man", "Captain America"]
      assert question.correct_answer == 0
      assert question.explanation == "Hulk is the strongest Avenger."
    end
  end

  describe "add_player/3" do
    test "adds a player to the state" do
      state = state_fixture()
      player_id = UUID.uuid4()

      assert %State{players: [player]} = Quizzes.add_player(state, player_id, "Joe")
      assert %Player{name: "Joe", id: ^player_id} = player
    end

    test "sets first player to the host" do
      state = state_fixture()
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      assert %{players: [joe, jane]} =
               state
               |> Quizzes.add_player(player1_id, "Joe")
               |> Quizzes.add_player(player2_id, "Jane")

      assert joe.is_host == true
      assert jane.is_host == false
    end
  end

  describe "answer_question/3" do
    test "sets the current_answer for the specified player" do
      state = state_fixture()
      player1_id = UUID.uuid4()

      state = %{players: [player1]} = Quizzes.add_player(state, player1_id, "Joe")
      assert player1.current_answer == nil

      %{players: [player1]} = Quizzes.answer_question(state, player1_id, 1)
      assert player1.current_answer == 1
    end
  end

  describe "next_question/1" do
    test "increments the current question" do
      state = state_fixture()
      assert state.current_question == 0

      state = Quizzes.next_question(state)
      assert state.current_question == 1
    end

    test "updates each player's score and resets their current answer" do
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      state =
        state_fixture()
        |> Quizzes.add_player(player1_id, "Leonardo")
        |> Quizzes.add_player(player2_id, "Donatello")
        |> Quizzes.answer_question(player1_id, 0)
        |> Quizzes.answer_question(player2_id, 1)
        |> Quizzes.next_question()

      assert state.current_question == 1
      assert [leo, don] = state.players
      assert leo.score == 1
      assert leo.current_answer == nil
      assert don.score == 0
      assert don.current_answer == nil
    end
  end

  describe "current_state/1" do
    test "returns :new if the quiz has no title" do
      state = %State{}
      assert Quizzes.current_state(state) == :new
    end

    test "returns :generating if the quiz has a title, but no questions" do
      state = %State{title: "Marvel characters"}
      assert Quizzes.current_state(state) == :generating
    end

    test "returns :joining if the quiz has a title and questions, but the current_question is nil" do
      state = %State{
        title: "Marvel characters",
        questions: [
          %{
            text: "Who is the strongest Avenger?",
            answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
            correct_answer: 0,
            explanation: "Hulk is the strongest Avenger."
          },
          %{
            text: "Who is the smartest Avenger?",
            answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
            correct_answer: 2,
            explanation: "Iron Man is the smartest Avenger."
          }
        ],
        current_question: nil
      }

      assert Quizzes.current_state(state) == :joining
    end

    test "returns :answering if current_question is valid but not all players have answered" do
      state = %State{
        title: "Marvel characters",
        questions: [
          %{
            text: "Who is the strongest Avenger?",
            answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
            correct_answer: 0,
            explanation: "Hulk is the strongest Avenger."
          }
        ],
        current_question: 0,
        players: [
          %Player{id: 1, name: "Joe", current_answer: 0},
          %Player{id: 2, name: "Jane", current_answer: nil}
        ]
      }

      assert Quizzes.current_state(state) == :answering
    end

    test "returns :reviewing if all players have answered" do
      state = %State{
        title: "Marvel characters",
        questions: [
          %{
            text: "Who is the strongest Avenger?",
            answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
            correct_answer: 0,
            explanation: "Hulk is the strongest Avenger."
          }
        ],
        current_question: 0,
        players: [
          %Player{id: 1, name: "Joe", current_answer: 1},
          %Player{id: 2, name: "Jane", current_answer: 2}
        ]
      }

      assert Quizzes.current_state(state) == :reviewing
    end

    test "returns :complete if the current_question is greater than the number of answers" do
      state = %State{
        title: "Marvel characters",
        questions: [
          %{
            text: "Who is the strongest Avenger?",
            answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
            correct_answer: 0,
            explanation: "Hulk is the strongest Avenger."
          }
        ],
        current_question: 1
      }

      assert Quizzes.current_state(state) == :complete
    end
  end

  describe "get_player/2" do
    test "retrieves the player with the given id" do
      state = state_fixture()
      id = UUID.uuid4()

      state = Quizzes.add_player(state, id, "Joe")
      assert %Player{name: "Joe", id: ^id} = Quizzes.get_player(state, id)
    end

    test "returns nil if the player is not found" do
      state = state_fixture()
      id = UUID.uuid4()

      assert Quizzes.get_player(state, id) == nil
    end
  end

  defp state_fixture do
    attrs = %{
      title: "Marvel characters",
      questions: [
        %{
          text: "Who is the strongest Avenger?",
          answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
          correct_answer: 0,
          explanation: "Hulk is the strongest Avenger."
        },
        %{
          text: "Who is the smartest Avenger?",
          answers: ["Hulk", "Thor", "Iron Man", "Captain America"],
          correct_answer: 2,
          explanation: "Iron Man is the smartest Avenger."
        }
      ]
    }

    Quizzes.create_quiz(attrs)
  end
end
