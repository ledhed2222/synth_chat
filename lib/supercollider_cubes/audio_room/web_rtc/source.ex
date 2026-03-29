defmodule SupercolliderCubes.AudioRoom.WebRTC.Source do
  @moduledoc """
  A simple Membrane source. Registers itself with PubSub
  and then sends all Opus frames it receives from PubSub out as
  Membrane.Buffers for the WebRTC pipeline.
  """
  use Membrane.Source

  alias Phoenix.PubSub

  def_output_pad(:output,
    accepted_format: Membrane.Opus,
    flow_control: :push
  )

  @impl true
  def handle_init(_context, _opts) do
    PubSub.subscribe(SupercolliderCubes.PubSub, "opus_frames")
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
