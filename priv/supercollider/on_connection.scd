// Sent by the Elixir app each time it connects to the SuperCollider command channel.
// ~whenReady (defined in boot_scsynth.scd) ensures boot_scsynth has fully completed
// its setup before any of this runs, regardless of connection timing.

~whenReady.({
    SynthDef(\testTone, {|freq=440, amp=0.3, filterCutoff=2000|
        var sig = SinOsc.ar(freq);
        sig = RLPF.ar(sig, filterCutoff, 0.3);
        sig = sig * amp;
        Out.ar(0, sig ! 2);
    }).add;

    s.sync;

    ~startSynth.(\testTone, [\freq, 440, \amp, 0.3, \filterCutoff, 2000]);

    "Instrument ready: testTone at 440Hz".postln;
});
