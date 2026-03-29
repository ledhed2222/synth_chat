// Boots scsynth and sets up audio streaming via DiskOut -> /tmp/audio.fifo (in-memory pipe).
// Commands are received via stdin (piped from /tmp/sc_pipe by entrypoint.sh).
s.options.device = "default";
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 0;
s.options.sampleRate = 48000;
s.options.blockSize = 64;
s.options.memSize = 1048576;

// ~whenReady is available as soon as sclang evaluates this file, before scsynth has
// finished booting. All other .scd files should call this instead of s.waitForBoot
// to ensure boot_scsynth.scd has fully finished its own setup first.
~bootComplete = false;
~whenReady = {|func|
    fork {
        while({ ~bootComplete.not }, { 0.1.wait });
        func.value;
    };
};

s.waitForBoot({
    "Calling `waitForBoot`...".post;

    // 1920-frame buffer (power of 2 * 2) — flushes every 960 frames = 20ms,
    // matching a single Opus frame exactly to avoid bursty delivery.
    ~diskBuf = Buffer.alloc(s, 1920, 2);

    s.sync;

    // Write to /tmp/audio.fifo — a named pipe in tmpfs, not disk.
    // socat must already have the read end open before this call.
    ~diskBuf.write("/tmp/audio.fifo", "raw", "int16", 0, 0, true);

    s.sync;

    SynthDef(\diskWriter, {|buf=0|
        DiskOut.ar(buf, In.ar(0, 2));
    }).add;

    s.sync;

    ~writer = Synth.tail(s.defaultGroup, \diskWriter, [\buf, ~diskBuf.bufnum]);

    ~startSynth = {|defName, args|
        if(~synth.notNil, { ~synth.free });
        ~synth = Synth.before(~writer, defName, args ? []);
    };

    ~bootComplete = true;

    "done!".postln;
    "Streaming audio to /tmp/audio.fifo on port 7777".postln;
});
