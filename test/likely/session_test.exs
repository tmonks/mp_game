defmodule MPG.Likely.SessionTest do
  use ExUnit.Case, async: false

  alias MPG.Likely.Player
  alias MPG.Likely.Question
  alias MPG.Likely.State
  alias MPG.Likely.Session

  import Mox
  import MPG.Fixtures.OpenAI

  @player_id UUID.uuid4()
  @server_id "likely_test"

  setup do
    set_mox_global()
    server_pid = start_supervised!({Session, [name: @server_id]})
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)

    %{server: server_pid}
  end

  test "can ping the server" do
    assert Session.ping(@server_id) == :pong
  end

  test "get_state/1 retrieves the state" do
    assert {:ok, %State{}} = Session.get_state(@server_id)
  end

  test "get_state/1 returns an error tuple if server doesn't exist" do
    assert {:error, :not_found} = Session.get_state("non_existent_server")
  end

  test "add_player/3 adds a new player" do
    Session.add_player(@server_id, @player_id, "Alice")

    assert_receive({:state_updated, _action, state})
    assert [%Player{name: "Alice", current_vote: nil}] = state.players
  end

  test "cast_vote/3 sets a player's vote" do
    player2_id = UUID.uuid4()
    Session.add_player(@server_id, @player_id, "Alice")
    assert_receive({:state_updated, _action, _state})

    Session.add_player(@server_id, player2_id, "Bob")
    assert_receive({:state_updated, _action, _state})

    Session.cast_vote(@server_id, @player_id, player2_id)

    assert_receive({:state_updated, _action, state})
    alice = Enum.find(state.players, &(&1.id == @player_id))
    assert alice.current_vote == player2_id
  end

  test "start_game/1 triggers background question generation" do
    mock_likely_questions()

    Session.start_game(@server_id)

    # start_game broadcast
    assert_receive({:state_updated, :start_game, _state})

    # questions generated
    assert_receive({:state_updated, :set_questions, state})
    assert length(state.questions) == 10

    assert %Question{text: "Who's most likely to survive a zombie apocalypse?"} =
             Enum.at(state.questions, 0)
  end

  test "next_question/1 progresses state" do
    stub_likely_questions()

    Session.add_player(@server_id, @player_id, "Alice")
    assert_receive({:state_updated, _action, _state})

    Session.start_game(@server_id)
    assert_receive({:state_updated, :start_game, _state})
    assert_receive({:state_updated, :set_questions, state})
    assert state.current_question == nil

    # start the game (sets current_question to 0)
    Session.next_question(@server_id)
    assert_receive({:state_updated, :next_question, state})
    assert state.current_question == 0

    # vote and advance
    Session.cast_vote(@server_id, @player_id, @player_id)
    assert_receive({:state_updated, _action, _state})

    Session.next_question(@server_id)
    assert_receive({:state_updated, :next_question, state})
    assert state.current_question == 1
    assert Map.has_key?(state.results, 0)
  end

  test "next_question/1 triggers roast generation when all questions done" do
    player2_id = UUID.uuid4()

    # set up a state near the end
    state = %State{
      server_id: @server_id,
      started: true,
      players: [
        %Player{
          id: @player_id,
          name: "Alice",
          is_host: true,
          color: "Gold",
          current_vote: player2_id
        },
        %Player{
          id: player2_id,
          name: "Bob",
          is_host: false,
          color: "DeepPink",
          current_vote: @player_id
        }
      ],
      questions: [%Question{text: "Who's most likely to be late?"}],
      current_question: 0,
      results: %{},
      roasts: %{}
    }

    Session.set_state(@server_id, state)
    assert_receive({:state_updated, :set_state, _state})

    mock_likely_roasts(%{
      "Alice" => "You're always fashionably late... to everything.",
      "Bob" => "Bob, you're the reason we have clocks."
    })

    Session.next_question(@server_id)

    # next_question broadcast (now in :roasting status)
    assert_receive({:state_updated, :next_question, state})
    assert state.current_question == 1
    assert map_size(state.roasts) == 0

    # roasts generated
    assert_receive({:state_updated, :set_roasts, state})
    assert map_size(state.roasts) == 2
  end
end
