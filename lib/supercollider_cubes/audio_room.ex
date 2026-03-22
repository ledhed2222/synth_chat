defmodule SupercolliderCubes.AudioRoom do
  @moduledoc """
  Membrane pipeline that captures SuperCollider audio via TCP and streams it via WebRTC.
  Uses Membrane.WebRTC.Sink with Phoenix signaling.
  """
  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.WebRTC
  alias SupercolliderCubes.TcpAudioSource

  @impl true
  def handle_init(_ctx, signaling_id: signaling_id) do
    spec = [
      child(:audio_source, %TcpAudioSource{
        host: System.get_env("SC_HOST", "localhost"),
        port: 7777
      })
      |> child(:opus_encoder, Membrane.Opus.Encoder)
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

  defp get_stun_server do
    case System.get_env("STUN_SERVER", "") do
      "" ->
        []

      url ->
        [%{urls: url}]
    end
  end
end
