defmodule SupercolliderCubes.AudioRoom do
  @moduledoc """
  Manages AudioRoom Membrane pipelines for each WebRTC peer.
  Each peer gets their own pipeline instance.
  """
  use GenServer
  require Logger

  alias SupercolliderCubes.AudioRoom

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec add_peer(String.t()) :: :ok
  def add_peer(peer_id) do
    GenServer.call(__MODULE__, {:add_peer, peer_id})
  end

  @spec remove_peer(String.t()) :: :ok
  def remove_peer(peer_id) do
    GenServer.call(__MODULE__, {:remove_peer, peer_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting AudioRoom")

    # Start the encoding pipeline
    {:ok, _supervisor, _pid} =
      Membrane.Pipeline.start_link(AudioRoom.EncodingPipeline)

    {:ok, %{pipelines: %{}}}
  end

  @impl true
  def handle_call({:add_peer, peer_id}, _from, state) do
    Logger.info("Starting pipeline for peer: #{peer_id}")

    # Start a new pipeline for this peer with Phoenix signaling
    {:ok, _supervisor, pipeline} =
      Membrane.Pipeline.start_link(AudioRoom.WebRTC, signaling_id: "audio:#{peer_id}")

    pipelines = Map.put(state.pipelines, peer_id, pipeline)

    {:reply, :ok, %{state | pipelines: pipelines}}
  end

  @impl true
  def handle_call({:remove_peer, peer_id}, _from, state) do
    Logger.info("Stopping pipeline for peer: #{peer_id}")

    case Map.get(state.pipelines, peer_id) do
      nil ->
        {:reply, :ok, state}

      pipeline ->
        Membrane.Pipeline.terminate(pipeline)
        pipelines = Map.delete(state.pipelines, peer_id)
        {:reply, :ok, %{state | pipelines: pipelines}}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end
end
