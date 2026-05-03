defmodule SupercolliderCubes.AudioRoom.WebRTC do
  @moduledoc """
  A membrane pipeline for WebRTC comms with an individual listener
  """
  use Membrane.Pipeline
  require Membrane.Logger

  alias Membrane.WebRTC
  alias SupercolliderCubes.AudioRoom.WebRTC.Source

  @type stun_server :: %{urls: String.t()}

  @impl true
  def handle_init(_ctx, signaling_id: signaling_id) do
    spec = [
      child(:audio_source, Source)
      |> via_in(:input, options: [kind: :audio])
      |> child(:webrtc_sink, %WebRTC.Sink{
        signaling: Membrane.WebRTC.PhoenixSignaling.new(signaling_id),
        tracks: [:audio],
        ice_servers: get_stun_server()
      })
    ]

    {[spec: spec], %{signaling_id: signaling_id}}
  end

  @impl true
  def handle_child_notification(notification, :webrtc_sink, _ctx, state) do
    Membrane.Logger.debug("WebRTC notification: #{inspect(notification)}")
    {[], state}
  end

  @impl true
  def handle_child_notification(notification, element, _ctx, state) do
    Membrane.Logger.debug(
      "Received notification from #{inspect(element)}: #{inspect(notification)}"
    )

    {[], state}
  end

  @spec get_stun_server() :: [stun_server()]
  defp get_stun_server do
    case System.get_env("STUN_SERVER", "") do
      "" ->
        []

      url ->
        [%{urls: url}]
    end
  end
end
