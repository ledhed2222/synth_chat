defmodule SupercolliderCubes.PhysicsStateTest do
  use ExUnit.Case, async: false

  alias SupercolliderCubes.PhysicsState

  # PhysicsState is a singleton shared across the whole test run, so tests
  # only assert on values they themselves just set, never on defaults.
  defp sync, do: :sys.get_state(Process.whereis(PhysicsState))

  defp get_block(label) do
    PhysicsState.get_all() |> Enum.find(&(&1.label == label))
  end

  test "update/1 sets the exact position sent" do
    PhysicsState.update([%{"label" => "frequency", "xNormalized" => 0.9, "yNormalized" => 0.2}])
    sync()

    block = get_block("frequency")
    assert_in_delta block.xNormalized, 0.9, 0.0001
    assert_in_delta block.yNormalized, 0.2, 0.0001
  end

  test "lock/2 is only released by the peer that holds it" do
    PhysicsState.lock("filterCutoff", "peer-a")
    sync()
    assert get_block("filterCutoff").lockedBy == "peer-a"

    PhysicsState.unlock("filterCutoff", "peer-b")
    sync()
    assert get_block("filterCutoff").lockedBy == "peer-a"

    PhysicsState.unlock("filterCutoff", "peer-a")
    sync()
    assert get_block("filterCutoff").lockedBy == nil
  end

  test "sc_synth:connected doesn't crash the server and leaves block state untouched" do
    before_blocks = PhysicsState.get_all()

    Phoenix.PubSub.broadcast(SupercolliderCubes.PubSub, "sc_synth:connected", :sc_synth_connected)
    sync()

    assert Process.alive?(Process.whereis(PhysicsState))
    assert PhysicsState.get_all() == before_blocks
  end
end
