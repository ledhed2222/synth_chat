defmodule SupercolliderCubes.PhysicsState do
  @moduledoc """
  Canonical server-side block state: positions and locks.
  Clients receive the full state on join so they start in sync.
  Positions are stored normalized (0.0–1.0), independent of canvas dimensions.
  """
  use GenServer

  alias SupercolliderCubes.ScSynth

  # Defaults match the BLOCKS array in PhysicsCanvas.js (800x800 canvas).
  @default_blocks [
    %{
      label: "frequency",
      color: "#d79921",
      xNormalized: 0.5,
      yNormalized: 0.125
    },
    %{
      label: "filterCutoff",
      color: "#ff80ed",
      xNormalized: 0.375,
      yNormalized: 0.125
    }
  ]

  @type label_change_position :: %{required(String.t()) => term()}

  # Client API
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec get_all() :: list(map())
  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end

  @spec update(list(map())) :: :ok
  def update(changes) do
    GenServer.cast(__MODULE__, {:update, changes})
  end

  @spec lock(String.t(), String.t()) :: :ok
  def lock(label, by) do
    GenServer.cast(__MODULE__, {:lock, label, by})
  end

  @spec unlock(String.t(), String.t()) :: :ok
  def unlock(label, by) do
    GenServer.cast(__MODULE__, {:unlock, label, by})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      blocks: Map.new(@default_blocks, fn block -> {block.label, block} end),
      locks: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    blocks =
      Enum.map(state.blocks, fn {label, block} ->
        Map.put(block, :lockedBy, Map.get(state.locks, label))
      end)

    {:reply, blocks, state}
  end

  @impl true
  def handle_cast({:update, changes}, state) do
    changes
    |> Enum.each(&update_synth/1)

    blocks =
      changes
      |> Enum.reduce(state.blocks, fn change, acc ->
        %{"label" => label, "xNormalized" => x, "yNormalized" => y} = change
        %{:color => color} = get_in(state.blocks, [label])
        Map.put(acc, label, %{label: label, xNormalized: x, yNormalized: y, color: color})
      end)

    {:noreply, %{state | blocks: blocks}}
  end

  @impl true
  def handle_cast({:lock, label, by}, state) do
    {:noreply, %{state | locks: Map.put(state.locks, label, by)}}
  end

  @impl true
  def handle_cast({:unlock, label, by}, state) do
    locks =
      case Map.get(state.locks, label) do
        ^by -> Map.delete(state.locks, label)
        _ -> state.locks
      end

    {:noreply, %{state | locks: locks}}
  end

  @spec update_synth(label_change_position()) :: :ok
  defp update_synth(%{"label" => "frequency", "xNormalized" => x, "yNormalized" => y}) do
    freq = 200 + x * 1800
    amp = 1 - y
    ScSynth.send_command("~synth.set(\\freq, #{freq}, \\amp, #{amp})")
    :ok
  end

  defp update_synth(%{"label" => "filterCutoff", "xNormalized" => x, "yNormalized" => y}) do
    # convert position from 0..1 to -1..1
    pos = x * 2 - 1
    cutoff = 50 + (1 - y) * 7800
    ScSynth.send_command("~synth.set(\\cutoff, #{cutoff}, \\pos, #{pos})")
    :ok
  end
end
