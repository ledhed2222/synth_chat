defmodule SupercolliderCubes.AudioRoom.EncodingPipeline do
  @moduledoc """
  Membrane pipeline that captures SuperCollider audio via TCP, encodes it to
  Opus format, and outputs it to PubSub
  """
  use Membrane.Pipeline

  alias SupercolliderCubes.AudioRoom.EncodingPipeline

  @impl true
  def handle_init(_ctx, _opts) do
    spec = [
      child(:audio_source, %EncodingPipeline.Source{
        host: System.get_env("SC_HOST", "localhost"),
        port: 7777
      })
      |> child(:opus_encoder, %Membrane.Opus.Encoder{bitrate: 96_000})
      |> child(:audio_sink, EncodingPipeline.Sink)
    ]

    {[spec: spec], %{}}
  end
end
