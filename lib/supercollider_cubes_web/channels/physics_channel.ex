defmodule SupercolliderCubesWeb.PhysicsChannel do
  @moduledoc """
  Handles all the updates of the shared physics canvas state between users
  """
  use SupercolliderCubesWeb, :channel

  alias SupercolliderCubes.PhysicsState

  @impl true
  def join("physics:lobby", _payload, socket) do
    {:ok, %{blocks: PhysicsState.get_all()}, socket}
  end

  @impl true
  def handle_in("lock-block", %{"block" => label, "by" => by} = msg, socket) do
    PhysicsState.lock(label, by)
    broadcast!(socket, "lock-block", msg)
    {:noreply, socket}
  end

  @impl true
  def handle_in("unlock-block", %{"block" => label, "by" => by} = msg, socket) do
    PhysicsState.unlock(label, by)
    broadcast!(socket, "unlock-block", msg)
    {:noreply, socket}
  end

  @impl true
  def handle_in("block-update", msg, socket) do
    %{"changes" => changes} = msg

    broadcast!(socket, "block-update", msg)

    # TODO use ecto changeset?
    changes
    |> PhysicsState.update()

    {:noreply, socket}
  end
end
