defmodule SupercolliderCubes.ScSynthTest do
  use ExUnit.Case, async: false

  alias SupercolliderCubes.ScSynth

  @topic "sc_synth:connected"

  test "only broadcasts sc_synth_connected once SC confirms the synth actually booted" do
    Phoenix.PubSub.subscribe(SupercolliderCubes.PubSub, @topic)
    socket = make_ref()

    # ~startSynth resets to the SynthDef's hardcoded defaults, so a resync
    # triggered before it actually runs would get silently discarded.
    # "Instrument ready" alone (without the marker) must not trigger a resync.
    send(Process.whereis(ScSynth), {:tcp, socket, "Instrument ready: testTone at 440Hz\n"})
    refute_receive :sc_synth_connected, 100

    send(Process.whereis(ScSynth), {:tcp, socket, "sc3> SC_SYNTH_READY\n"})
    assert_receive :sc_synth_connected, 100
  end
end
