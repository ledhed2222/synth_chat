defmodule SupercolliderCubesWeb.PhysicsChannel do
  @moduledoc """
  Handles all the updates of the shared physics canvas state between users
  """
  use SupercolliderCubesWeb, :channel
  require Logger

  alias SupercolliderCubes.ScSynth

  @impl true
  def join("physics:lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("lock-block", msg, socket) do
    broadcast!(socket, "lock-block", msg)
    {:noreply, socket}
  end

  @impl true
  def handle_in("unlock-block", msg, socket) do
    broadcast!(socket, "unlock-block", msg)
    {:noreply, socket}
  end

  @impl true
  def handle_in("block-update", msg, socket) do
    %{"changes" => changes} = msg

    changes
    |> Enum.each(fn change ->
      %{
        "label" => label,
        "xNormalized" => x,
        "yNormalized" => y
      } = change

      case label do
        "frequency" ->
          freq = 200 + x * 1800
          amp = 1 - y
          ScSynth.send_command("~synth.set(\\freq, #{freq}, \\amp, #{amp})")
          :ok

        "filterCutoff" ->
          # convert position from 0..1 to -1..1
          pos = x * 2 - 1
          cutoff = 200 + y * 7800

          ScSynth.send_command("~synth.set(\\cutoff, #{cutoff}, \\pos, #{pos})")

          :ok

        _ ->
          :ok
      end
    end)

    broadcast!(socket, "block-update", msg)
    {:noreply, socket}
  end
end
