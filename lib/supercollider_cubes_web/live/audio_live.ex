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

  @impl true
  def handle_event(
        "client-audio-update",
        %{"frequency" => %{"x" => fx, "y" => fy}, "filterCutoff" => %{"x" => cx}},
        socket
      ) do
    freq = 200 + fx * 1800
    amp = 1 - fy
    filter_cutoff = 200 + cx * 7800

    SupercolliderCubes.ScSynth.send_command(
      "~synth.set(\\freq, #{freq}, \\amp, #{amp}, \\filterCutoff, #{filter_cutoff})"
    )

    {:noreply, socket}
  end
end
