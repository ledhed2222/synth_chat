defmodule SupercolliderCubesWeb.PhysicsChannel do
  @moduledoc """
  Handles all the updates of the shared physics canvas state between users
  """
  use SupercolliderCubesWeb, :channel

  @impl true
  def join("physics:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
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
      %{"label" => label} = change

      case label do
        "frequency" ->
          %{"xNormalized" => x, "yNormalized" => y} = change
          freq = 200 + x * 1800
          amp = 1 - y
          SupercolliderCubes.ScSynth.send_command("~synth.set(\\freq, #{freq}, \\amp, #{amp})")
          :ok

        "filterCutoff" ->
          %{"xNormalized" => x} = change
          filter_cutoff = 200 + x * 7800
          SupercolliderCubes.ScSynth.send_command("~synth.set(\\filterCutoff, #{filter_cutoff})")
          :ok

        _ ->
          :ok
      end
    end)

    broadcast!(socket, "block-update", msg)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
