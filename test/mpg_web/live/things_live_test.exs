defmodule MPGWeb.ThingsLiveTest do
  use MPGWeb.ConnCase
  import Phoenix.LiveViewTest

  alias MPG.Things.Game

  setup %{conn: conn} do
    conn = init_test_session(conn, %{})
    session_id = UUID.uuid4()
    conn = put_session(conn, :session_id, session_id)

    # Restart the session to clear out any state
    Supervisor.terminate_child(MPG.Supervisor, MPG.Things.Game)
    Supervisor.restart_child(MPG.Supervisor, MPG.Things.Game)

    # subscribe to PubSub
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, "things_session")

    {:ok, conn: conn, session_id: session_id}
  end

  test "if the player with the session_id does not exist, prompts for name", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Join"
  end

  test "can join the game", %{conn: conn, session_id: session_id} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert_receive({:state_updated, _state})
    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{conn: conn, session_id: session_id} do
    Game.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "host gets a 'New Question' button which opens a modal", %{
    conn: conn,
    session_id: session_id
  } do
    Game.add_player(:things_session, session_id, "Host")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#new-question-button")
    refute has_element?(view, "#new-question-modal")

    # click the New Question button
    view |> element("#new-question-button") |> render_click()

    # check that the modal is now visible
    assert has_element?(view, "#new-question-modal")
  end

  test "other players cannot see the 'New Question' button", ctx do
    Game.add_player(:things_session, UUID.uuid4(), "Host")
    Game.add_player(:things_session, ctx.session_id, "Player")

    {:ok, view, _html} = live(ctx.conn, ~p"/")

    refute has_element?(view, "#new-question-button")
  end

  test "host can set a new question", ctx do
    Game.add_player(:things_session, ctx.session_id, "Host")

    {:ok, view, _html} = live(ctx.conn, ~p"/")

    view
    |> element("#new-question-button")
    |> render_click()

    assert_patch(view, "/new_question")

    view
    |> form("#new-question-form", %{question: "Things that are red"})
    |> render_submit()

    assert_patch(view, "/")

    assert_receive({:state_updated, _state})
    assert has_element?(view, "#current-question", "Things that are red")
  end

  test "indicates that players that have provided an answer are ready", %{
    conn: conn,
    session_id: session_id
  } do
    Game.add_player(:things_session, session_id, "Tom")
    id = UUID.uuid4()
    Game.add_player(:things_session, id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#player-#{id} [data-role=ready-check-mark]")

    # Set the player's answer
    Game.set_player_answer(:things_session, id, "bananas")
    assert_receive({:state_updated, _state})
    :timer.sleep(100)

    assert has_element?(view, "#player-#{id} [data-role=ready-check-mark]")
  end

  test "shows the current question", %{conn: conn, session_id: session_id} do
    Game.new_question(:things_session, "Things that are red")
    Game.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#current-question", "Things that are red")
  end

  test "players see a waiting message if the host has not set a question", %{
    conn: conn,
    session_id: session_id
  } do
    Game.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#waiting-message")
  end

  test "player can submit answer", %{conn: conn, session_id: session_id} do
    Game.new_question(:things_session, "Things that are yummy")
    Game.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#answer-form", %{answer: "bananas"})
    |> render_submit()

    assert_receive({:state_updated, _state})
    assert has_element?(view, "#my-answer", "bananas")
  end

  test "answers are only show after all players have answered", %{
    conn: conn,
    session_id: session_id
  } do
    id2 = UUID.uuid4()
    Game.add_player(:things_session, session_id, "Player 1")
    Game.add_player(:things_session, id2, "Player 2")

    Game.set_player_answer(:things_session, session_id, "apple")

    {:ok, view, _html} = live(conn, ~p"/")

    refute has_element?(view, "#unrevealed-answers")

    Game.set_player_answer(:things_session, id2, "banana")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#unrevealed-answers", "apple")
    assert has_element?(view, "#unrevealed-answers", "banana")
  end

  test "when all players have answered, a 'reveal' button appears", %{
    conn: conn,
    session_id: session_id
  } do
    Game.new_question(:things_session, "Things that are red")
    Game.add_player(:things_session, session_id, "Player 1")
    id2 = UUID.uuid4()
    Game.add_player(:things_session, id2, "Player 2")

    Game.set_player_answer(:things_session, session_id, "apple")
    {:ok, view, _html} = live(conn, ~p"/")

    refute has_element?(view, "#reveal-button")

    Game.set_player_answer(:things_session, id2, "banana")
    assert_receive({:state_updated, _state})
    :timer.sleep(100)

    assert has_element?(view, "#reveal-button")
  end

  test "moves the player icon next to their answer once they've been revealed", ctx do
    player1_id = ctx.session_id
    player2_id = UUID.uuid4()
    Game.add_player(:things_session, player1_id, "Bart")
    Game.add_player(:things_session, player2_id, "Homer")

    Game.set_player_answer(:things_session, player1_id, "apple")
    Game.set_player_answer(:things_session, player2_id, "banana")

    {:ok, view, _html} = live(ctx.conn, ~p"/")

    # player icon shown in player list
    assert has_element?(view, "#player-list #player-#{player2_id}")
    # player icon not shown with answer
    refute has_element?(view, "#answer-#{player2_id} #player-#{player2_id}")

    Game.set_player_to_revealed(:things_session, player2_id)

    assert_received({:state_updated, _state})
    :timer.sleep(100)

    # player icon no longer shown in player list
    refute has_element?(view, "#player-list #player-#{player2_id}")
    # player icon shown with answer
    assert has_element?(view, "#answer-#{player2_id} #player-#{player2_id}")
  end

  test "receives and renders state updates", ctx do
    player1_id = ctx.session_id
    Game.add_player(:things_session, player1_id, "Player 1")

    {:ok, view, _html} = live(ctx.conn, ~p"/")

    Game.new_question(:things_session, "Things that are awesome")

    assert_receive({:state_updated, _state})
    # TODO: is there a way to do this without needing a sleep?
    :timer.sleep(100)
    assert has_element?(view, "#current-question", "Things that are awesome")
  end
end
