defmodule SupercolliderCubesWeb.AudioLive do
  use SupercolliderCubesWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:connected, false)
     |> assign(:muted, true)}
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

  @impl true
  def handle_event("client-audio-update", %{"pos_x" => pos_x, "pos_y" => pos_y}, socket) do
    freq = 200 + (pos_x / 800) * 1800
    amp = 1 - (pos_y / 800)

    SupercolliderCubes.ScSynth.send_command(
      "~synth.set(\\freq, #{freq}, \\amp, #{amp})"
    )

    {:noreply, socket}
  end
end
