defmodule SupercolliderCubes.AudioRoom.WebRTC.Source do
  @moduledoc """
  A simple Membrane source. Registers itself with Multiplexer
  and then sends all Opus frames it receives from the Multiplexer out as
  Membrane.Buffers for the WebRTC pipeline.
  """
  use Membrane.Source

  alias SupercolliderCubes.AudioRoom.Multiplexer

  def_output_pad(:output,
    accepted_format: Membrane.Opus,
    flow_control: :push
  )

  @impl true
  def handle_init(_context, _opts) do
    Multiplexer.register_listener(self())
    {[], %{playing: false}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[stream_format: {:output, %Membrane.Opus{channels: 2}}], %{state | playing: true}}
  end

  @impl true
  def handle_info({:audio_frame, buffer}, _ctx, state) do
    if state.playing do
      {[buffer: {:output, buffer}], state}
    else
      {[], state}
    end
  end
end
