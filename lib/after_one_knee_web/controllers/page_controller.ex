defmodule AfterOneKneeWeb.PageController do
  use AfterOneKneeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
