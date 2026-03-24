defmodule SupercolliderCubesWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "audio:*", SupercolliderCubesWeb.AudioChannel
  channel "physics:*", SupercolliderCubesWeb.PhysicsChannel

  @impl true
  def connect(params, socket, _connect_info) do
    {:ok, assign(socket, :uuid, params["uuid"])}
  end

  @impl true
  def id(socket) do
    "user_socket:#{socket.assigns.uuid}"
  end
end
