defmodule SupercolliderCubesWeb.PageController do
  use SupercolliderCubesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def get_uuid do
    Ecto.UUID.generate()
  end
end
