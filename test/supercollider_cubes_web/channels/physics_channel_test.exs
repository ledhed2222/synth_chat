defmodule SupercolliderCubesWeb.PhysicsChannelTest do
  use SupercolliderCubesWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      SupercolliderCubesWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(SupercolliderCubesWeb.PhysicsChannel, "physics:lobby")

    %{socket: socket}
  end

  test "lock-block broadcasts to physics:lobby", %{socket: socket} do
    push(socket, "lock-block", %{"block" => "frequency", "by" => "user_id"})
    assert_broadcast "lock-block", %{"block" => "frequency", "by" => "user_id"}
  end

  test "unlock-block broadcasts to physics:lobby", %{socket: socket} do
    push(socket, "unlock-block", %{"block" => "frequency", "by" => "user_id"})
    assert_broadcast "unlock-block", %{"block" => "frequency", "by" => "user_id"}
  end

  test "block-update broadcasts to physics:lobby", %{socket: socket} do
    changes = [%{"label" => "frequency", "xNormalized" => 0.6, "yNormalized" => 0.3}]
    push(socket, "block-update", %{"changes" => changes})
    assert_broadcast "block-update", %{"changes" => ^changes}
  end
end
