// Sent by the Elixir app each time it connects to the SuperCollider command channel.
// ~whenReady (defined in boot_scsynth.scd) ensures boot_scsynth has fully completed
// its setup before any of this runs, regardless of connection timing.
~whenReady.({
    SynthDef(\testTone, {
        arg freq=440, pos=0, amp=0.3, cutoff=2000;
        // Rich chord spread across many frequency bands so Opus VBR allocates
        // real bits rather than collapsing to near-zero for a pure tone.
        // Stereo test: full amp left, 10% right (20dB difference).
        var sig, pannedSig;
        sig = SinOsc.ar([
          freq / 4,
          freq / 2,
          freq,
          freq * 2,
          freq * 4,
          freq * 8,
        ]).sum * amp;
        sig = RLPF.ar(sig, cutoff);
        pannedSig = Pan2.ar(sig, pos);
        Out.ar(0, pannedSig);
    }).add;

    s.sync;

    ~startSynth.(\testTone);

    "Instrument ready: testTone at 440Hz".postln;
});
