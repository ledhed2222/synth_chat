defmodule SupercolliderCubesWeb.PageController do
  use SupercolliderCubesWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  @spec get_uuid() :: Ecto.UUID.t()
  def get_uuid do
    Ecto.UUID.generate()
  end
end
