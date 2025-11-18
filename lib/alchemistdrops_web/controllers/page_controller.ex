defmodule AlchemistdropsWeb.PageController do
  use AlchemistdropsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
