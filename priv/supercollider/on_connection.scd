// Sent by the Elixir app each time it connects to the SuperCollider command channel.
// ~whenReady (defined in boot_scsynth.scd) ensures boot_scsynth has fully completed
// its setup before any of this runs, regardless of connection timing.

~whenReady.({
    SynthDef(\testTone, {|freq=440, amp=0.3|
        var sig = SinOsc.ar(freq) * amp;
        Out.ar(0, sig ! 2);
    }).add;

    s.sync;

    ~startSynth.(\testTone, [\freq, 440, \amp, 0.3]);

    "Instrument ready: testTone at 440Hz".postln;
});
