defmodule SupercolliderCubes.AudioRoom.EncodingPipeline.Source do
  @moduledoc """
  Membrane source that reads raw PCM audio from a TCP connection.
  Connects to the SuperCollider Docker container's audio stream.
  """
  use Membrane.Source

  alias Membrane.Buffer

  def_options(
    host: [
      spec: String.t(),
      default: "localhost",
      description: "TCP server host"
    ],
    port: [
      spec: :inet.port_number(),
      default: 7777,
      description: "TCP server port"
    ]
  )

  def_output_pad(:output,
    accepted_format: %Membrane.RawAudio{
      sample_format: :s16le,
      sample_rate: 48_000,
      channels: 2
    },
    flow_control: :push
  )

  @impl true
  def handle_init(_ctx, opts) do
    state = %{
      host: opts.host |> String.to_charlist(),
      port: opts.port,
      socket: nil,
      pts: 0,
      sample_rate: 48_000,
      channels: 2
    }

    {[], state}
  end

  @impl true
  def handle_playing(_ctx, state) do
    stream_format = %Membrane.RawAudio{
      sample_format: :s16le,
      sample_rate: state.sample_rate,
      channels: state.channels
    }

    case :gen_tcp.connect(state.host, state.port, [:binary, active: true]) do
      {:ok, socket} ->
        {[stream_format: {:output, stream_format}], %{state | socket: socket}}

      {:error, reason} ->
        raise "Failed to connect to audio stream: #{inspect(reason)}"
    end
  end

  @impl true
  def handle_info({:tcp, _socket, data}, _ctx, state) do
    bytes_per_sample = 2 * state.channels
    num_samples = byte_size(data) / bytes_per_sample
    duration_ns = trunc(num_samples / state.sample_rate * 1_000_000_000)

    buffer = %Buffer{
      payload: data,
      pts: state.pts
    }

    new_pts = state.pts + duration_ns

    {[buffer: {:output, buffer}], %{state | pts: new_pts}}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, _ctx, state) do
    {[end_of_stream: :output], state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, _ctx, _state) do
    raise "TCP error: #{inspect(reason)}"
  end
end
