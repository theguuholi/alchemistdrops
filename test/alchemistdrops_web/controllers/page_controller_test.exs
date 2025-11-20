defmodule AlchemistdropsWeb.PageControllerTest do
  use AlchemistdropsWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Log in"
  end
end
