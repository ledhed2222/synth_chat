defmodule SupercolliderCubes.AudioRoom.EncodingPipeline.Sink do
  @moduledoc """
  A Membrane sink that receives Opus packets from EncodingPipeline and just
  forwards them along to PubSub
  """
  use Membrane.Sink

  alias Phoenix.PubSub

  def_input_pad(:input, accepted_format: Membrane.Opus)

  @impl true
  def handle_buffer(:input, buffer, _ctx, _state) do
    PubSub.broadcast(
      SupercolliderCubes.PubSub,
      "opus_frames",
      {:audio_frame, buffer}
    )

    {[], %{}}
  end
end
