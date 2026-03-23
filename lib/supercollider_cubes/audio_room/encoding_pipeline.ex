defmodule SupercolliderCubes.AudioRoom.EncodingPipeline do
  @moduledoc """
  Membrane pipeline that captures SuperCollider audio via TCP, encodes it to
  Opus format, and outputs it to the Multiplexer.
  """
  use Membrane.Pipeline

  alias SupercolliderCubes.AudioRoom.EncodingPipeline.Sink
  alias SupercolliderCubes.AudioRoom.EncodingPipeline.Source

  @impl true
  def handle_init(_ctx, _opts) do
    spec = [
      child(:audio_source, %Source{
        host: System.get_env("SC_HOST", "localhost"),
        port: 7777
      })
      |> child(:opus_encoder, Membrane.Opus.Encoder)
      |> child(:audio_sink, Sink)
    ]

    {[spec: spec], %{}}
  end
end
