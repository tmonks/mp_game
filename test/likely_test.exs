defmodule MPG.LikelyTest do
  use ExUnit.Case

  alias MPG.Likely
  alias MPG.Likely.Player
  alias MPG.Likely.Question
  alias MPG.Likely.State

  describe "set_questions/2" do
    test "sets the questions" do
      state = %State{questions: []}

      questions = [
        %{text: "Who's most likely to survive a zombie apocalypse?"},
        %{text: "Who's most likely to become famous?"}
      ]

      assert %State{questions: [%Question{}, %Question{}]} =
               Likely.set_questions(state, questions)
    end
  end

  describe "add_player/3" do
    test "adds a player to the state" do
      state = %State{players: []}
      player_id = UUID.uuid4()

      assert %State{players: [player]} = Likely.add_player(state, player_id, "Alice")
      assert %Player{name: "Alice", id: ^player_id} = player
    end

    test "sets first player as host" do
      state = %State{players: []}
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      assert %{players: [alice, bob]} =
               state
               |> Likely.add_player(player1_id, "Alice")
               |> Likely.add_player(player2_id, "Bob")

      assert alice.is_host == true
      assert bob.is_host == false
    end

    test "assigns colors to players" do
      state = %State{players: []}
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      %{players: [p1, p2]} =
        state
        |> Likely.add_player(player1_id, "Alice")
        |> Likely.add_player(player2_id, "Bob")

      assert p1.color != nil
      assert p2.color != nil
      assert p1.color != p2.color
    end
  end

  describe "cast_vote/3" do
    test "sets current_vote on the voting player" do
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      state =
        %State{players: []}
        |> Likely.add_player(player1_id, "Alice")
        |> Likely.add_player(player2_id, "Bob")

      %{players: [alice, bob]} = Likely.cast_vote(state, player1_id, player2_id)

      assert alice.current_vote == player2_id
      assert bob.current_vote == nil
    end

    test "player can vote for themselves" do
      player_id = UUID.uuid4()

      state =
        %State{players: []}
        |> Likely.add_player(player_id, "Alice")

      %{players: [alice]} = Likely.cast_vote(state, player_id, player_id)

      assert alice.current_vote == player_id
    end
  end

  describe "next_question/1" do
    test "sets current_question to 0 when nil" do
      state = %State{
        players: [],
        questions: [%Question{text: "test"}],
        current_question: nil
      }

      assert %{current_question: 0} = Likely.next_question(state)
    end

    test "increments current_question and preserves results" do
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      # Results are already tallied by cast_vote
      state = %State{
        players: [
          %Player{id: player1_id, name: "Alice", current_vote: player2_id},
          %Player{id: player2_id, name: "Bob", current_vote: player2_id}
        ],
        questions: [%Question{text: "Q1"}, %Question{text: "Q2"}],
        current_question: 0,
        results: %{0 => %{player2_id => 2}}
      }

      new_state = Likely.next_question(state)

      assert new_state.current_question == 1
      assert new_state.results[0] == %{player2_id => 2}
    end

    test "clears all players' current_vote" do
      player1_id = UUID.uuid4()
      player2_id = UUID.uuid4()

      state = %State{
        players: [
          %Player{id: player1_id, name: "Alice", current_vote: player2_id},
          %Player{id: player2_id, name: "Bob", current_vote: player1_id}
        ],
        questions: [%Question{text: "Q1"}, %Question{text: "Q2"}],
        current_question: 0,
        results: %{}
      }

      %{players: [alice, bob]} = Likely.next_question(state)

      assert alice.current_vote == nil
      assert bob.current_vote == nil
    end
  end

  describe "set_roasts/2" do
    test "sets the roasts map on state" do
      state = %State{players: [], roasts: %{}}
      roasts = %{"player1" => "You're the one most likely to..."}

      assert %State{roasts: ^roasts} = Likely.set_roasts(state, roasts)
    end
  end

  describe "current_status/1" do
    test "returns :new when game has not started" do
      state = %State{questions: [], started: false}
      assert Likely.current_status(state) == :new
    end

    test "returns :generating when started but no questions yet" do
      state = %State{questions: [], started: true}
      assert Likely.current_status(state) == :generating
    end

    test "returns :joining when questions exist but current_question is nil" do
      state = %State{
        questions: [%Question{text: "Q1"}],
        current_question: nil,
        started: true
      }

      assert Likely.current_status(state) == :joining
    end

    test "returns :voting when not all players have voted" do
      state = %State{
        started: true,
        questions: [%Question{text: "Q1"}],
        current_question: 0,
        players: [
          %Player{id: "1", name: "Alice", current_vote: "2"},
          %Player{id: "2", name: "Bob", current_vote: nil}
        ],
        roasts: %{}
      }

      assert Likely.current_status(state) == :voting
    end

    test "returns :revealing when all players have voted" do
      state = %State{
        started: true,
        questions: [%Question{text: "Q1"}],
        current_question: 0,
        players: [
          %Player{id: "1", name: "Alice", current_vote: "2"},
          %Player{id: "2", name: "Bob", current_vote: "1"}
        ],
        roasts: %{}
      }

      assert Likely.current_status(state) == :revealing
    end

    test "returns :roasting when all questions done but no roasts yet" do
      state = %State{
        started: true,
        questions: [%Question{text: "Q1"}],
        current_question: 1,
        roasts: %{}
      }

      assert Likely.current_status(state) == :roasting
    end

    test "returns :complete when all questions done and roasts exist" do
      state = %State{
        started: true,
        questions: [%Question{text: "Q1"}],
        current_question: 1,
        roasts: %{"1" => "roast text"}
      }

      assert Likely.current_status(state) == :complete
    end
  end

  describe "all_players_voted?/1" do
    test "returns true when all players have voted" do
      state = %State{
        players: [
          %Player{id: "1", current_vote: "2"},
          %Player{id: "2", current_vote: "1"}
        ]
      }

      assert Likely.all_players_voted?(state) == true
    end

    test "returns false when not all players have voted" do
      state = %State{
        players: [
          %Player{id: "1", current_vote: "2"},
          %Player{id: "2", current_vote: nil}
        ]
      }

      assert Likely.all_players_voted?(state) == false
    end
  end

  describe "tally_votes/1" do
    test "counts votes correctly" do
      state = %State{
        players: [
          %Player{id: "1", name: "Alice", current_vote: "2"},
          %Player{id: "2", name: "Bob", current_vote: "2"},
          %Player{id: "3", name: "Charlie", current_vote: "1"}
        ]
      }

      tally = Likely.tally_votes(state)

      assert tally == %{"2" => 2, "1" => 1}
    end

    test "ignores nil votes" do
      state = %State{
        players: [
          %Player{id: "1", name: "Alice", current_vote: "2"},
          %Player{id: "2", name: "Bob", current_vote: nil}
        ]
      }

      tally = Likely.tally_votes(state)

      assert tally == %{"2" => 1}
    end
  end

  describe "vote_results_for_question/2" do
    test "returns sorted results for a question" do
      player1_id = "p1"
      player2_id = "p2"
      player3_id = "p3"

      state = %State{
        players: [
          %Player{id: player1_id, name: "Alice"},
          %Player{id: player2_id, name: "Bob"},
          %Player{id: player3_id, name: "Charlie"}
        ],
        results: %{
          0 => %{player2_id => 2, player1_id => 1}
        }
      }

      results = Likely.vote_results_for_question(state, 0)

      assert [
               {%Player{name: "Bob"}, 2},
               {%Player{name: "Alice"}, 1},
               {%Player{name: "Charlie"}, 0}
             ] =
               results
    end

    test "works when results are tallied incrementally via cast_vote" do
      # cast_vote updates results as votes come in, so vote_results_for_question
      # always reads from results — no fallback needed.
      state = %State{
        started: true,
        players: [
          %Player{id: "p1", name: "Alice"},
          %Player{id: "p2", name: "Bob"},
          %Player{id: "p3", name: "Charlie"}
        ],
        questions: [%Question{text: "Q1"}, %Question{text: "Q2"}],
        current_question: 0,
        results: %{}
      }

      state =
        state
        |> Likely.cast_vote("p1", "p2")
        |> Likely.cast_vote("p2", "p2")
        |> Likely.cast_vote("p3", "p1")

      assert Likely.current_status(state) == :revealing

      results = Likely.vote_results_for_question(state, state.current_question)

      # Bob should have 2 votes, Alice 1, Charlie 0
      assert [{%Player{name: "Bob"}, 2}, {%Player{name: "Alice"}, 1}, {%Player{name: "Charlie"}, 0}] =
               results
    end
  end

  describe "vote_summary/1" do
    test "builds summary of which questions each player won" do
      state = %State{
        players: [
          %Player{id: "1", name: "Alice"},
          %Player{id: "2", name: "Bob"}
        ],
        questions: [
          %Question{text: "Who's most likely to be late?"},
          %Question{text: "Who's most likely to laugh first?"}
        ],
        results: %{
          0 => %{"1" => 2, "2" => 1},
          1 => %{"2" => 3}
        }
      }

      summary = Likely.vote_summary(state)

      assert {"Alice", "1", ["Who's most likely to be late?"]} =
               Enum.find(summary, fn {name, _, _} -> name == "Alice" end)

      assert {"Bob", "2", ["Who's most likely to laugh first?"]} =
               Enum.find(summary, fn {name, _, _} -> name == "Bob" end)
    end
  end

  describe "get_player/2" do
    test "retrieves the player with the given id" do
      state = %State{players: []}
      id = UUID.uuid4()

      state = Likely.add_player(state, id, "Alice")
      assert %Player{name: "Alice", id: ^id} = Likely.get_player(state, id)
    end

    test "returns nil if the player is not found" do
      state = %State{players: []}
      assert Likely.get_player(state, UUID.uuid4()) == nil
    end
  end
end
