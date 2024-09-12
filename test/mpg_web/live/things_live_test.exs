defmodule MPGWeb.ThingsLiveTest do
  use MPGWeb.ConnCase
  import Phoenix.LiveViewTest

  alias MPG.Things.Session

  setup %{conn: conn} do
    conn = init_test_session(conn, %{})
    session_id = UUID.uuid4()
    conn = put_session(conn, :session_id, session_id)

    # Restart the session to clear out any state
    Supervisor.terminate_child(MPG.Supervisor, MPG.Things.Session)
    Supervisor.restart_child(MPG.Supervisor, MPG.Things.Session)

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
    assert has_element?(view, "#player-#{session_id} [data-role=player-name]", "Me")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{session_id} [data-role=player-name]", "Me")
    refute has_element?(view, "#join-form")
  end

  test "lists current player as 'Me'", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{session_id} [data-role=player-name]", "Me")
  end

  test "shows 'No answer yet' for other players that have not provided an answer", %{
    conn: conn,
    session_id: session_id
  } do
    Session.add_player(:things_session, session_id, "Tom")
    id = UUID.uuid4()
    Session.add_player(:things_session, id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{id}", "Peter")
    assert has_element?(view, "#player-#{id} [data-role=answer]", "No answer yet")
  end

  test "shows 'Ready' for other players that have provided an answer", %{
    conn: conn,
    session_id: session_id
  } do
    Session.add_player(:things_session, session_id, "Tom")
    id = UUID.uuid4()
    Session.add_player(:things_session, id, "Peter")
    Session.set_player_answer(:things_session, id, "bananas")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-#{id}", "Peter")
    assert has_element?(view, "#player-#{id} [data-role=answer]", "Ready")
  end

  test "shows the current question", %{conn: conn} do
    Session.new_question(:things_session, "Things that are red")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#current-question", "Things that are red")
  end

  test "player can submit answer", %{conn: conn, session_id: session_id} do
    Session.add_player(:things_session, session_id, "Peter")

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
    Session.add_player(:things_session, session_id, "Player 1")
    Session.add_player(:things_session, id2, "Player 2")

    Session.set_player_answer(:things_session, session_id, "apple")

    {:ok, view, _html} = live(conn, ~p"/")

    refute has_element?(view, "#unrevealed-answers")

    Session.set_player_answer(:things_session, id2, "banana")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#unrevealed-answers", "apple")
    assert has_element?(view, "#unrevealed-answers", "banana")
  end

  test "when all players have answered, a 'reveal' button appears", %{
    conn: conn,
    session_id: session_id
  } do
    Session.add_player(:things_session, session_id, "Player 1")
    id2 = UUID.uuid4()
    Session.add_player(:things_session, id2, "Player 2")

    Session.set_player_answer(:things_session, session_id, "apple")
    {:ok, view, _html} = live(conn, ~p"/")

    refute has_element?(view, "#reveal-button")

    Session.set_player_answer(:things_session, id2, "banana")
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#reveal-button")
  end

  test "clicking the 'reveal' button removes player's answer from answers list", ctx do
    # session with both players answered
    player1_id = ctx.session_id
    player2_id = UUID.uuid4()
    Session.add_player(:things_session, player1_id, "Player 1")
    Session.add_player(:things_session, player2_id, "Player 2")

    Session.set_player_answer(:things_session, player1_id, "apple")
    Session.set_player_answer(:things_session, player2_id, "banana")

    {:ok, view, _html} = live(ctx.conn, ~p"/")

    assert has_element?(view, "#unrevealed-answers", "apple")

    view
    |> render_click("reveal")

    assert_receive({:state_updated, _state})
    refute has_element?(view, "#unrevealed-answers", "apple")
  end

  test "shows answers next to other players that have been revealed", ctx do
    player1_id = ctx.session_id
    player2_id = UUID.uuid4()
    Session.add_player(:things_session, player1_id, "Player 1")
    Session.add_player(:things_session, player2_id, "Player 2")

    Session.set_player_answer(:things_session, player1_id, "apple")
    Session.set_player_answer(:things_session, player2_id, "banana")

    Session.set_player_to_revealed(:things_session, player2_id)

    {:ok, view, _html} = live(ctx.conn, ~p"/")

    assert has_element?(view, "#player-#{player2_id} [data-role=answer]", "banana")
  end

  test "receives and renders state updates", ctx do
    player1_id = ctx.session_id
    Session.add_player(:things_session, player1_id, "Player 1")

    {:ok, view, _html} = live(ctx.conn, ~p"/")

    Session.new_question(:things_session, "Things that are awesome")

    assert_receive({:state_updated, _state})
    # TODO: is there a way to do this without needing a sleep?
    :timer.sleep(100)
    assert has_element?(view, "#current-question", "Things that are awesome")
  end
end
