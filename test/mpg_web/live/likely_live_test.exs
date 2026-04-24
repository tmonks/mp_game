defmodule MPGWeb.LikelyLiveTest do
  use MPGWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox
  import MPG.Fixtures.OpenAI

  alias MPG.Likely.Player
  alias MPG.Likely.Question
  alias MPG.Likely.Session
  alias MPG.Likely.State

  @server_id "likely_session"

  setup %{conn: conn} do
    set_mox_global()

    conn = init_test_session(conn, %{})

    session_id = UUID.uuid4()
    conn = put_session(conn, :session_id, session_id)

    start_supervised!({Session, name: @server_id})

    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)

    stub_likely_questions()

    {:ok, conn: conn, session_id: session_id}
  end

  test "visiting /likely redirects to a random server ID", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path}}} = live(conn, ~p"/likely")

    assert new_path =~ ~r"/likely/[a-z0-9]+"

    server_id = new_path |> String.split("/") |> List.last()

    assert {:ok, %State{server_id: ^server_id}} = Session.get_state(server_id)
  end

  test "redirects to home page if the server ID is invalid", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path, flash: flash}}} =
      live(conn, ~p"/likely/invalidid")

    assert new_path == "/"
    assert flash["error"] == "Game not found"
  end

  test "if the player with the session_id does not exist, prompts for name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#join-form")
  end

  test "can join the game", %{conn: conn, session_id: session_id} do
    {:ok, view, _html} = live(conn, ~p"/likely/#{@server_id}")

    view
    |> form("#join-form", %{player_name: "Alice"})
    |> render_submit()

    assert_receive({:state_updated, _action, _state})
    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Ali")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{conn: conn, session_id: session_id} do
    Session.add_player(@server_id, session_id, "Alice")

    {:ok, view, _html} = live(conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Ali")
    refute has_element?(view, "#join-form")
  end

  test "host sees 'Start Game' button after joining", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    view
    |> form("#join-form", %{player_name: "Host"})
    |> render_submit()

    assert_receive({:state_updated, _action, _state})
    assert has_element?(view, "#start-button", "Start Game")
  end

  test "shows status messages", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")
    assert_receive({:state_updated, _action, _state})

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#current-status", "Waiting for host to start")
  end

  test "host can start the game and questions are generated", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")
    assert_receive({:state_updated, _action, _state})

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    view
    |> element("#start-button")
    |> render_click()

    assert_receive({:state_updated, :start_game, _state})

    assert_receive({:state_updated, :set_questions, state})
    assert length(state.questions) == 10
    assert has_element?(view, "#current-status", "Ready to start!")
  end

  test "shows game code while waiting", ctx do
    Session.add_player(@server_id, ctx.session_id, "Alice")
    assert_receive({:state_updated, _action, _state})

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#game-code", @server_id)
  end

  test "host can start first question after questions are generated", ctx do
    start_game(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#next-button")

    view
    |> element("#next-button")
    |> render_click()

    assert_receive({:state_updated, :next_question, state})
    assert state.current_question == 0
  end

  test "shows question counter and question text", ctx do
    start_game_and_begin(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#question-counter", "1 of 10")

    assert has_element?(
             view,
             "#question-text",
             "Who's most likely to survive a zombie apocalypse?"
           )
  end

  test "shows player vote buttons during voting", ctx do
    start_game_and_begin(ctx.session_id)
    player2_id = add_player("Bob")

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#vote-#{ctx.session_id}")
    assert has_element?(view, "#vote-#{player2_id}")
  end

  test "player can vote by clicking a player button", ctx do
    start_game_and_begin(ctx.session_id)
    player2_id = add_player("Bob")

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    view
    |> element("#vote-#{player2_id}")
    |> render_click()

    assert_receive({:state_updated, :cast_vote, state})
    host = Enum.find(state.players, &(&1.id == ctx.session_id))
    assert host.current_vote == player2_id
  end

  test "after voting, shows voted checkmark on player avatar", ctx do
    start_game_and_begin(ctx.session_id)
    _player2_id = add_player("Bob")

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    refute has_element?(view, "#player-#{ctx.session_id} [data-role=ready-check-mark]")

    view
    |> element("#vote-#{ctx.session_id}")
    |> render_click()

    assert_receive({:state_updated, _action, _state})
    assert has_element?(view, "#player-#{ctx.session_id} [data-role=ready-check-mark]")
  end

  test "after all players vote, host sees Next Question button", ctx do
    start_game_and_begin(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    # only one player, vote for self
    view
    |> element("#vote-#{ctx.session_id}")
    |> render_click()

    assert_receive({:state_updated, _action, _state})
    assert has_element?(view, "#next-button")
  end

  test "after all players vote, shows ranked results", ctx do
    start_game_and_begin(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    view
    |> element("#vote-#{ctx.session_id}")
    |> render_click()

    assert_receive({:state_updated, _action, _state})
    assert has_element?(view, "#vote-results")
    assert has_element?(view, "#result-#{ctx.session_id}")
  end

  test "host can advance to next question from revealing", ctx do
    start_game_and_begin(ctx.session_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    # vote and move to revealing
    view
    |> element("#vote-#{ctx.session_id}")
    |> render_click()

    assert_receive({:state_updated, _action, _state})

    view
    |> element("#next-button")
    |> render_click()

    assert_receive({:state_updated, :next_question, state})
    assert state.current_question == 1
    assert has_element?(view, "#question-counter", "2 of 10")
  end

  test "shows roast cards when game is complete", ctx do
    player2_id = UUID.uuid4()

    state = %State{
      server_id: @server_id,
      started: true,
      players: [
        %Player{id: ctx.session_id, name: "Alice", is_host: true, color: "Gold"},
        %Player{id: player2_id, name: "Bob", is_host: false, color: "DeepPink"}
      ],
      questions: [%Question{text: "Q1"}],
      current_question: 1,
      results: %{0 => %{ctx.session_id => 1, player2_id => 1}},
      roasts: %{
        ctx.session_id => "Alice, you absolute legend.",
        player2_id => "Bob, what can we say."
      }
    }

    Session.set_state(@server_id, state)

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#roast-results")
    assert has_element?(view, "#roast-#{ctx.session_id}", "Alice, you absolute legend.")
    assert has_element?(view, "#roast-#{player2_id}", "Bob, what can we say.")
  end

  test "host sees 'Play Again' when complete", ctx do
    state = %State{
      server_id: @server_id,
      started: true,
      players: [
        %Player{id: ctx.session_id, name: "Alice", is_host: true, color: "Gold"}
      ],
      questions: [%Question{text: "Q1"}],
      current_question: 1,
      results: %{0 => %{ctx.session_id => 1}},
      roasts: %{ctx.session_id => "Nice one, Alice."}
    }

    Session.set_state(@server_id, state)

    {:ok, view, _html} = live(ctx.conn, ~p"/likely/#{@server_id}")

    assert has_element?(view, "#play-again-button", "Play Again")
  end

  # Helper functions

  defp start_game(player_id) do
    Session.add_player(@server_id, player_id, "Host")
    assert_receive({:state_updated, _action, _state})

    Session.start_game(@server_id)
    assert_receive({:state_updated, :start_game, _state})
    assert_receive({:state_updated, :set_questions, _state})
  end

  defp start_game_and_begin(player_id) do
    start_game(player_id)

    Session.next_question(@server_id)
    assert_receive({:state_updated, :next_question, _state})
  end

  defp add_player(name) do
    id = UUID.uuid4()
    Session.add_player(@server_id, id, name)
    assert_receive({:state_updated, _action, _state})
    id
  end
end
