defmodule SupercolliderCubes.AudioRoom.Multiplexer do
  @moduledoc """
  Effectively an application-wide buffer for opus-encoded audio frames, ready
  to transmit over WebRTC
  """
  use GenServer

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_frame(frame) do
    GenServer.cast(__MODULE__, {:send_frame, frame})
  end

  def register_listener(pid) do
    GenServer.cast(__MODULE__, {:register_listener, pid})
  end

  def unregister_listener(pid) do
    GenServer.cast(__MODULE__, {:unregister_listener, pid})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{listeners: MapSet.new()}}
  end

  @impl true
  def handle_cast({:send_frame, frame}, state) do
    state[:listeners]
    |> Enum.each(fn listener ->
      send(listener, {:audio_frame, frame})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:register_listener, pid}, state) do
    Process.monitor(pid)
    new_listeners = state[:listeners] |> MapSet.put(pid)
    {:noreply, %{state | listeners: new_listeners}}
  end

  @impl true
  def handle_cast({:unregister_listener, pid}, state) do
    new_listeners = state[:listeners] |> MapSet.delete(pid)
    {:noreply, %{state | listeners: new_listeners}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_listeners = state[:listeners] |> MapSet.delete(pid)
    {:noreply, %{state | listeners: new_listeners}}
  end
end
