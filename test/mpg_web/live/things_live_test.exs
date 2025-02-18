defmodule MPGWeb.ThingsLiveTest do
  use MPGWeb.ConnCase
  import Phoenix.LiveViewTest

  alias MPG.Things.Session
  alias MPG.Things.State

  @server_id "things_test"

  setup %{conn: conn} do
    conn = init_test_session(conn, %{})

    # populate a session_id on the conn
    session_id = UUID.uuid4()
    conn = put_session(conn, :session_id, session_id)

    start_supervised!({Session, [name: @server_id]})

    # subscribe to PubSub
    :ok = Phoenix.PubSub.subscribe(MPG.PubSub, @server_id)

    {:ok, conn: conn, session_id: session_id}
  end

  test "visiting /things redirects to a random server ID", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path}}} = live(conn, ~p"/things")

    assert new_path =~ ~r"/things/[a-z0-9]+"

    # retrieve the server name from the `name` URL param
    server_id = new_path |> String.split("/") |> List.last()

    # Session GenServer started with that name
    assert {:ok, %State{server_id: ^server_id}} = Session.get_state(server_id)
  end

  test "redirects to home page if the server ID is invalid", %{conn: conn} do
    {:error, {:live_redirect, %{to: new_path, flash: flash}}} =
      live(conn, ~p"/things/invalidid")

    assert new_path == "/"
    assert flash["error"] == "Game not found"
  end

  test "if the player with the session_id does not exist, prompts for name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

    assert has_element?(view, "#join-form")
  end

  test "can join the game", %{conn: conn, session_id: session_id} do
    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

    view
    |> form("#join-form", %{player_name: "Peter"})
    |> render_submit()

    assert_receive({:state_updated, _state})
    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "loads user from session_id if it exists", %{conn: conn, session_id: session_id} do
    Session.add_player(@server_id, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

    assert has_element?(view, "#player-#{session_id}[data-role=avatar]", "Pet")
    refute has_element?(view, "#join-form")
  end

  test "host is prompted to enter a question right after joining", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    assert has_element?(view, "#new-question-form")
  end

  test "host gets a 'New Question' button which displays the form", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")
    Session.new_question(@server_id, "Things that are red")
    Session.set_player_answer(@server_id, ctx.session_id, "apple")
    Session.reveal_player(@server_id, ctx.session_id, "12345")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    assert has_element?(view, "#new-question-button")
    refute has_element?(view, "#new-question-form")

    # click the New Question button
    view |> element("#new-question-button") |> render_click()

    # check that the form is now visible
    assert has_element?(view, "#new-question-form")
  end

  test "host's 'New Question' button only shows when all players have been revealed", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")
    Session.new_question(@server_id, "Things that are red")
    Session.set_player_answer(@server_id, ctx.session_id, "apple")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    refute has_element?(view, "#new-question-button")

    Session.reveal_player(@server_id, ctx.session_id, "12345")

    assert_receive({:state_updated, _state})
    :timer.sleep(100)

    assert has_element?(view, "#new-question-button")
  end

  test "other players cannot see the 'New Question' button", ctx do
    Session.add_player(@server_id, UUID.uuid4(), "Host")
    Session.add_player(@server_id, ctx.session_id, "Player")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    refute has_element?(view, "#new-question-button")
  end

  test "host can set a new question", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")
    Session.new_question(@server_id, "Things that are red")
    Session.set_player_answer(@server_id, ctx.session_id, "apple")
    Session.reveal_player(@server_id, ctx.session_id, "12345")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    view
    |> element("#new-question-button")
    |> render_click()

    assert_patch(view, ~p"/things/things_test/new_question")

    view
    |> form("#new-question-form", %{question: "Things that are red"})
    |> render_submit()

    assert_patch(view, ~p"/things/things_test")

    assert_receive({:state_updated, _state})
    assert has_element?(view, "#current-question", "Things that are red")
  end

  test "host gets an error if they try to submit an empty question", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")
    Session.new_question(@server_id, "Things that are red")
    Session.set_player_answer(@server_id, ctx.session_id, "apple")
    Session.reveal_player(@server_id, ctx.session_id, "12345")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    view
    |> element("#new-question-button")
    |> render_click()

    assert_patch(view, ~p"/things/things_test/new_question")

    assert view
           |> form("#new-question-form", %{question: ""})
           |> render_change() =~ "Question can&#39;t be blank"
  end

  test "host can click a button on the form to generate a new question", ctx do
    Session.add_player(@server_id, ctx.session_id, "Host")

    {:ok, view, _html} = live(ctx.conn, ~p"/things/things_test/new_question")

    assert has_element?(view, "#new-question-form")
    assert has_element?(view, "input#question[value='']")

    view
    |> element("#generate-question-button")
    |> render_click()

    assert has_element?(view, "input#question")
    # no longer empty
    refute has_element?(view, "input#question[value='']")
  end

  test "shows check marks for players that have provided an answer", ctx do
    player1_id = ctx.session_id
    player2_id = UUID.uuid4()

    Session.add_player(@server_id, player1_id, "Player 1")
    Session.new_question(@server_id, "Things that are red")
    Session.add_player(@server_id, player2_id, "Player 2")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")
    refute has_element?(view, "#player-#{player2_id} [data-role=ready-check-mark]")

    # Set the player's answer
    Session.set_player_answer(@server_id, player2_id, "bananas")
    assert_receive({:state_updated, _state})
    :timer.sleep(100)

    assert has_element?(view, "#player-#{player2_id} [data-role=ready-check-mark]")
  end

  test "stops showing check marks after all players have answered", ctx do
    player1_id = ctx.session_id
    player2_id = UUID.uuid4()

    Session.add_player(@server_id, player1_id, "Player 1")
    Session.new_question(@server_id, "Things that are yellow")
    Session.add_player(@server_id, player2_id, "Player 2")
    # Set Player 1's answer
    Session.set_player_answer(@server_id, player1_id, "bananas")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    # Player 1 has check mark
    assert has_element?(view, "#player-#{player1_id} [data-role=ready-check-mark]")

    # Set Player 2's answer
    Session.set_player_answer(@server_id, player2_id, "peeps")
    assert_receive({:state_updated, _state})
    :timer.sleep(100)

    # Player 1 no longer has check mark
    refute has_element?(view, "#player-#{player1_id} [data-role=ready-check-mark]")
  end

  test "shows the current question", %{conn: conn, session_id: session_id} do
    Session.new_question(@server_id, "Things that are red")
    Session.add_player(@server_id, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

    assert has_element?(view, "#current-question", "Things that are red")
  end

  test "players see a waiting message if the host has not set a question", %{
    conn: conn,
    session_id: session_id
  } do
    Session.add_player(@server_id, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/things/things_test")

    assert has_element?(view, "#waiting-message")
  end

  test "players can see the code to give others to join while waiting", ctx do
    Session.add_player(@server_id, ctx.session_id, "Peter")

    {:ok, view, _html} = live(ctx.conn, ~p"/things/things_test")

    assert has_element?(view, "#game-code", "things_test")
  end

  # TODO: fix this test
  @tag :skip
  test "submit answer button is disabled until the player enters something", ctx do
    Session.new_question(@server_id, "Things that are yummy")
    Session.add_player(@server_id, ctx.session_id, "Peter")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    assert has_element?(view, "#answer-form button[disabled]")

    view
    |> form("#answer-form", %{answer: "bananas"})
    |> render_change()

    assert has_element?(view, "#answer-form button")
    refute has_element?(view, "#answer-form button[disabled]")
  end

  test "player can submit answer", %{conn: conn, session_id: session_id} do
    Session.new_question(@server_id, "Things that are yummy")
    Session.add_player(@server_id, session_id, "Peter")

    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

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
    Session.add_player(@server_id, session_id, "Player 1")
    Session.add_player(@server_id, id2, "Player 2")

    Session.set_player_answer(@server_id, session_id, "apple")

    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

    refute has_element?(view, "#answers")

    Session.set_player_answer(@server_id, id2, "banana")

    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

    assert has_element?(view, "#answers", "apple")
    assert has_element?(view, "#answers", "banana")
  end

  test "when all players have answered, a 'reveal' button appears", %{
    conn: conn,
    session_id: session_id
  } do
    Session.new_question(@server_id, "Things that are red")
    Session.add_player(@server_id, session_id, "Player 1")
    id2 = UUID.uuid4()
    Session.add_player(@server_id, id2, "Player 2")

    Session.set_player_answer(@server_id, session_id, "apple")
    {:ok, view, _html} = live(conn, ~p"/things?id=things_test")

    refute has_element?(view, "#reveal-button")

    Session.set_player_answer(@server_id, id2, "banana")
    assert_receive({:state_updated, _state})
    :timer.sleep(100)

    assert has_element?(view, "#reveal-button")
  end

  test "players can select who guessed them and award a point", ctx do
    Session.new_question(@server_id, "Things that are red")

    # join players
    Session.add_player(@server_id, ctx.session_id, "Player 1")
    player2_id = UUID.uuid4()
    Session.add_player(@server_id, player2_id, "Player 2")
    player3_id = UUID.uuid4()
    Session.add_player(@server_id, player3_id, "Player 3")

    # set answers
    Session.set_player_answer(@server_id, ctx.session_id, "apple")
    Session.set_player_answer(@server_id, player2_id, "strawberry")
    Session.set_player_answer(@server_id, player3_id, "roses")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    assert has_element?(view, "#reveal-button")

    # clicking the button shows a modal
    view
    |> element("#reveal-button")
    |> render_click()

    assert_patch(view, ~p"/things/things_test/reveal")
    assert has_element?(view, "#reveal-modal")

    # select player 2 as the guesser
    view
    |> form("#reveal-form", %{guesser_id: player2_id})
    |> render_submit()

    assert_patch(view, ~p"/things/things_test")
    assert has_element?(view, "#player-#{player2_id} [data-role=score]", "1")
  end

  test "players cannot award themselves a point when revealing", ctx do
    Session.new_question(@server_id, "Things that are red")

    # join players
    Session.add_player(@server_id, ctx.session_id, "Player 1")
    player2_id = UUID.uuid4()
    Session.add_player(@server_id, player2_id, "Player 2")

    # set answers
    Session.set_player_answer(@server_id, ctx.session_id, "apple")
    Session.set_player_answer(@server_id, player2_id, "banana")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    view
    |> element("#reveal-button")
    |> render_click()

    assert_patch(view, ~p"/things/things_test/reveal")

    assert has_element?(view, "#guesser-select")
    refute has_element?(view, "option", "Player 1")
  end

  test "moves the player icon next to their answer once they've been revealed", ctx do
    player1_id = ctx.session_id
    player2_id = UUID.uuid4()
    Session.add_player(@server_id, player1_id, "Bart")
    Session.add_player(@server_id, player2_id, "Homer")

    Session.set_player_answer(@server_id, player1_id, "apple")
    Session.set_player_answer(@server_id, player2_id, "banana")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    # player icon shown in player list
    assert has_element?(view, "#player-list #player-#{player2_id}")
    # player icon not shown with answer
    refute has_element?(view, "#answer-#{player2_id} #player-#{player2_id}")

    Session.reveal_player(@server_id, player2_id, ctx.session_id)

    assert_received({:state_updated, _state})
    :timer.sleep(100)

    # player icon no longer shown in player list
    refute has_element?(view, "#player-list #player-#{player2_id}")
    # player icon shown with answer
    assert has_element?(view, "#answer-#{player2_id} #player-#{player2_id}")
  end

  test "receives and renders state updates", ctx do
    player1_id = ctx.session_id
    Session.add_player(@server_id, player1_id, "Player 1")

    {:ok, view, _html} = live(ctx.conn, ~p"/things?id=things_test")

    Session.new_question(@server_id, "Things that are awesome")

    assert_receive({:state_updated, _state})
    # TODO: is there a way to do this without needing a sleep?
    :timer.sleep(100)
    assert has_element?(view, "#current-question", "Things that are awesome")
  end

  test "can handle at least 8 players", ctx do
    player1_id = ctx.session_id
    Session.add_player(@server_id, player1_id, "P1")

    for i <- 2..8 do
      Session.add_player(@server_id, UUID.uuid4(), "Pl#{i}")
    end

    {:ok, _view, _html} = live(ctx.conn, ~p"/things?id=things_test")
    # open_browser(view)
  end
end
