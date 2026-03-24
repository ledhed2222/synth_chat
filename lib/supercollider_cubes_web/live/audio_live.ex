defmodule SupercolliderCubesWeb.AudioLive do
  use SupercolliderCubesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:connected, false)
     |> assign(:muted, true)
     |> assign(:stun_server, System.get_env("STUN_SERVER", ""))}
  end

  @impl true
  def handle_event("toggle_audio_click", _params, socket) do
    new_muted = !socket.assigns.muted
    event = if new_muted, do: "mute_audio", else: "unmute_audio"
    {:noreply, socket |> assign(:muted, new_muted) |> push_event(event, %{})}
  end

  @impl true
  def handle_event("connection_status", %{"connected" => connected}, socket) do
    {:noreply, assign(socket, :connected, connected)}
  end
end
