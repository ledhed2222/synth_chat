defmodule SupercolliderCubesWeb.AudioChannel do
  @moduledoc """
  Phoenix Channel for WebRTC signaling using Membrane.WebRTC.PhoenixSignaling.
  """
  use SupercolliderCubesWeb, :channel
  require Logger

  alias SupercolliderCubes.AudioRoom
  alias Membrane.WebRTC.PhoenixSignaling

  @impl true
  def join("audio:" <> peer_id, _params, socket) do
    Logger.info("Peer #{peer_id} joining audio channel")

    # Register this channel with Membrane's signaling system
    PhoenixSignaling.register_channel("audio:#{peer_id}", self())

    socket = assign(socket, :peer_id, peer_id)
    socket = assign(socket, :signaling_id, "audio:#{peer_id}")

    # Start a pipeline for this peer
    AudioRoom.add_peer(peer_id)

    {:ok, socket}
  end

  @impl true
  def handle_in(signaling_id, msg, socket) do
    # Forward signaling messages to Membrane
    msg = Jason.decode!(msg)

    # Membrane expects the same wrapped format we received
    # Just pass it through as-is
    PhoenixSignaling.signal(signaling_id, msg)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:membrane_webrtc_signaling, _pid, msg, _metadata}, socket) do
    push(socket, socket.assigns.signaling_id, inject_stereo_into_offer(msg))
    {:noreply, socket}
  end

  # Inject stereo=1;sprop-stereo=1 into the Opus fmtp line of the SDP offer.
  # ExWebRTCSink hardcodes the Opus codec params without an fmtp line, so browsers
  # default to mono decoding. This patches the offer before forwarding to the client.
  @spec inject_stereo_into_offer(map()) :: map()
  defp inject_stereo_into_offer(%{"type" => "sdp_offer", "data" => %{"sdp" => sdp} = data} = msg)
       when is_binary(sdp) do
    modified_sdp =
      if String.contains?(sdp, "a=fmtp:111") do
        sdp
      else
        Regex.replace(
          ~r/(a=rtpmap:111 opus\/48000\/2\r?\n)/,
          sdp,
          "\\1a=fmtp:111 minptime=10;useinbandfec=1;stereo=1;sprop-stereo=1\r\n"
        )
      end

    %{msg | "data" => %{data | "sdp" => modified_sdp}}
  end

  defp inject_stereo_into_offer(msg), do: msg

  @impl true
  def terminate(_reason, socket) do
    peer_id = socket.assigns[:peer_id]

    if peer_id do
      Logger.info("Peer #{peer_id} left audio channel")
      AudioRoom.remove_peer(peer_id)
    end

    :ok
  end
end
