defmodule SupercolliderCubesWeb.PageController do
  use SupercolliderCubesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
