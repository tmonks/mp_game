defmodule MPG.Things.SessionTest do
  use ExUnit.Case, async: true

  alias MPG.Things.Session
  alias MPG.Things.State

  setup do
    server = start_supervised!(Session)

    %{server: server}
  end

  test "can ping the server", %{server: server} do
    assert Session.ping(server) == :pong
  end

  test "can retrieve the state", %{server: server} do
    assert %State{} = Session.get_state(server)
  end
end
