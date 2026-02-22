defmodule VdrDemoWeb.HomeLiveTest do
  use VdrDemoWeb.ConnCase, async: true

  test "GET / loads", %{conn: conn} do
    conn = get(conn, ~p"/")
    _html = html_response(conn, 200)
  end
end
