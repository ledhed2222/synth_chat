defmodule SupercolliderCubes.AudioRoom.EncodingPipeline.Sink do
  @moduledoc """
  A Membrane sink that receives Opus packets from EncodingPipeline and just
  forwards them along to Multiplexer
  """
  use Membrane.Sink

  alias SupercolliderCubes.AudioRoom.Multiplexer

  def_input_pad(:input, accepted_format: Membrane.Opus)

  @impl true
  def handle_buffer(:input, buffer, _ctx, _state) do
    Multiplexer.send_frame(buffer)
    {[], %{}}
  end
end
