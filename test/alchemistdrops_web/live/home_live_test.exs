defmodule AlchemistdropsWeb.HomeLiveTest do
  use AlchemistdropsWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "HomeLive" do
    test "renders home page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "Welcome to Alchemistdrops"
    end
  end
end
