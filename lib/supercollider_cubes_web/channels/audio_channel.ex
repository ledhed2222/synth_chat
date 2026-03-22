defmodule SupercolliderCubesWeb.AudioChannel do
  @moduledoc """
  Phoenix Channel for WebRTC signaling using Membrane.WebRTC.PhoenixSignaling.
  """
  use SupercolliderCubesWeb, :channel

  require Logger

  alias SupercolliderCubes.AudioRoomManager
  alias Membrane.WebRTC.PhoenixSignaling

  @impl true
  def join("audio:" <> peer_id, _params, socket) do
    Logger.info("Peer #{peer_id} joining audio channel")

    # Register this channel with Membrane's signaling system
    PhoenixSignaling.register_channel("audio:#{peer_id}", self())

    socket = assign(socket, :peer_id, peer_id)
    socket = assign(socket, :signaling_id, "audio:#{peer_id}")

    # Start a pipeline for this peer
    AudioRoomManager.add_peer(peer_id)

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
    # Membrane already sends in the right format, just pass through
    push(socket, socket.assigns.signaling_id, msg)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    peer_id = socket.assigns[:peer_id]

    if peer_id do
      Logger.info("Peer #{peer_id} left audio channel")
      AudioRoomManager.remove_peer(peer_id)
    end

    :ok
  end
end
