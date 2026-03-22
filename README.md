# supercollider_cubes

A Phoenix/Elixir web app that streams live SuperCollider audio to browsers via WebRTC, with a Matter.js physics simulation that controls synth parameters in real time.

Click anywhere on the canvas to spawn a physics cube. Each cube's position maps to frequency and amplitude of the running synth. Click **Unmute** to hear it.

## How it works

```
┌──────────────────────────────────────────────┐
│  Docker Container (sc_audio)                 │
│                                              │
│  jackd (dummy driver, 48kHz)                 │
│    └── scsynth  ──► DiskOut UGen             │
│          ▲               │                   │
│        sclang        /tmp/audio.fifo         │
│          ▲           (in-memory pipe)        │
│          │               │                   │
│     TCP :57120       socat → TCP :7777       │
└──────────────────────────────────────────────┘
         ▲                      │
         │ SC commands          │ raw s16le PCM
         │                      ▼
┌──────────────────────────────────────────────┐
│  Phoenix App                                 │
│                                              │
│  ScSynth GenServer  TcpAudioSource           │
│  (sends .scd code)   └── Opus encoder        │
│                           └── WebRTC.Sink    │
│                                 │            │
│  AudioChannel  ◄──── PhoenixSignaling        │
│  (WebRTC signaling via Phoenix Channel)      │
└──────────────────────────────────────────────┘
                        │ WebRTC (Opus)
                        ▼
┌──────────────────────────────────────────────┐
│  Browser                                     │
│                                              │
│  AudioPlayer (JS hook)                       │
│  — connects on page load, starts muted       │
│  — Unmute/Mute button toggles audio.muted    │
│  — jitter buffer warms up in background      │
│                                              │
│  PhysicsCanvas (Matter.js)                   │
│  — click to spawn cubes                      │
│  — cube position → LiveView event            │
│  — LiveView → ScSynth → ~synth.set(...)      │
└──────────────────────────────────────────────┘
```

### SuperCollider container (`supercollider/`)

- **`entrypoint.sh`** — starts `jackd` (dummy driver), `sclang`, and two socat bridges:
  - `:7777` → serves raw PCM audio from `/tmp/audio.fifo`
  - `:57120` → forwards incoming TCP text to `/tmp/sc_pipe` (sclang's stdin)
- **`boot_scsynth.scd`** — loaded via SC's `startup.scd` on container start. Boots scsynth, sets up DiskOut to write stereo s16le audio to `/tmp/audio.fifo`, and exposes `~startSynth` and `~whenReady` helpers.
- **`priv/supercollider/on_connection.scd`** — sent by the Elixir app each time it connects to the command channel. Defines and starts the instrument synth using `~whenReady` (so it safely waits for boot to complete).

The DiskOut buffer is sized to flush every ~20ms — one Opus frame — to keep TCP delivery aligned with the encoder.

### Elixir backend

- **`ScSynth`** (`lib/supercollider_cubes/sc_synth.ex`) — GenServer that maintains a TCP connection to `:57120`. On connect it sends `on_connection.scd`. Exposes `send_command/1` for sending arbitrary SC code strings.
- **`TcpAudioSource`** (`lib/supercollider_cubes/tcp_audio_source.ex`) — Membrane source that reads raw s16le stereo PCM from the Docker container's `:7777` TCP stream and emits Membrane buffers.
- **`AudioRoom`** (`lib/supercollider_cubes/audio_room.ex`) — Membrane pipeline: `TcpAudioSource → Opus encoder → WebRTC.Sink`. One pipeline instance per connected peer.
- **`AudioRoomManager`** (`lib/supercollider_cubes/audio_room_manager.ex`) — GenServer that starts and stops `AudioRoom` pipelines as peers join and leave.
- **`AudioChannel`** (`lib/supercollider_cubes_web/channels/audio_channel.ex`) — Phoenix Channel on `audio:<peer_id>`. Bridges WebRTC signaling between the browser and Membrane's `PhoenixSignaling`.
- **`AudioLive`** (`lib/supercollider_cubes_web/live/audio_live.ex`) — LiveView that handles the Mute/Unmute button and `client-audio-update` events from the physics canvas. Maps cube `pos_x/pos_y` to synth frequency and amplitude via `ScSynth.send_command/1`.

### Frontend

- **`AudioPlayer`** (`assets/js/AudioPlayer.js`) — Phoenix LiveView hook. Connects WebRTC on page mount (muted). The Unmute button just sets `audio.muted = false` — the jitter buffer is already warmed up.
- **`PhysicsCanvas`** (`assets/js/PhysicsCanvas.js`) — Matter.js simulation. Click to spawn a 50×50 box; its spawn position is sent to the server as a `client-audio-update` event.

## Running locally

### Prerequisites

- Docker Desktop
- Elixir / Mix
- Node.js (for asset builds)

### Start everything

```bash
mix dev
```

This rebuilds the SuperCollider Docker image if needed, starts the container, and boots the Phoenix server. SC container logs are interleaved in cyan `[SC]` prefixed lines.

### First-time setup

```bash
mix setup   # installs deps, creates DB, builds assets
mix dev     # start everything
```

Navigate to `http://localhost:4000/audio`.

### Sending SuperCollider commands

```elixir
# From an IEx session attached to the running app:
SupercolliderCubes.ScSynth.send_command("~synth.set(\\freq, 880)")
```

### Adding a new synth

Edit `priv/supercollider/on_connection.scd`. Define your `SynthDef` and call `~startSynth` — it handles freeing the previous synth and correct node ordering:

```supercollider
~whenReady.({
    SynthDef(\mySynth, {|freq=440, amp=0.3|
        var sig = LFSaw.ar(freq) * amp;
        Out.ar(0, sig ! 2);
    }).add;

    s.sync;

    ~startSynth.(\mySynth, [\freq, 440, \amp, 0.3]);
});
```

No container restart needed — just reconnect the Elixir app to resend `on_connection.scd` (or restart the Phoenix server).

## Audio settings

| Setting     | Value              |
|-------------|--------------------|
| Sample rate | 48,000 Hz          |
| Channels    | 2 (stereo)         |
| Bit depth   | 16-bit signed LE   |
| Codec       | Opus (via WebRTC)  |
| Frame size  | ~20ms (960 samples)|

## File structure

```
supercollider/
├── Dockerfile               # Ubuntu 22.04 + SuperCollider + JACK + socat
├── docker-compose.yml
├── entrypoint.sh            # Container startup: JACK, sclang, socat bridges
└── boot_scsynth.scd         # SC boot: scsynth config, DiskOut, ~startSynth, ~whenReady

priv/supercollider/
└── on_connection.scd        # Sent on every Elixir→SC connect; defines instrument synth

lib/supercollider_cubes/
├── sc_synth.ex              # GenServer: TCP command channel to sclang
├── tcp_audio_source.ex      # Membrane source: reads raw PCM from TCP :7777
├── audio_room.ex            # Membrane pipeline: PCM → Opus → WebRTC
├── audio_room_manager.ex    # Manages one pipeline per WebRTC peer
└── application.ex

lib/supercollider_cubes_web/
├── channels/
│   ├── audio_channel.ex     # Phoenix Channel: WebRTC signaling bridge
│   └── user_socket.ex
└── live/
    ├── audio_live.ex        # LiveView: Mute button + physics→synth event handler
    └── audio_live.html.heex

assets/js/
├── AudioPlayer.js           # WebRTC hook: connects on mount, button toggles mute
└── PhysicsCanvas.js         # Matter.js: click-to-spawn cubes → synth control events

lib/mix/tasks/dev.ex         # `mix dev`: builds container + starts Phoenix
```
