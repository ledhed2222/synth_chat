#!/bin/bash

# Create required directories
mkdir -p /root/.local/share/SuperCollider/synthdefs

# Clean up any previous files
rm -f /tmp/.X*-lock
rm -f /tmp/sc_pipe
rm -f /tmp/audio.fifo

echo "Starting JACK with dummy driver..."
jackd -d dummy -r 48000 -p 1024 &
JACKD_PID=$!

sleep 2

# Create FIFOs before starting any readers or writers
mkfifo /tmp/audio.fifo
mkfifo /tmp/sc_pipe

# Start socat for audio streaming BEFORE sclang.
# DiskOut opens /tmp/audio.fifo for writing — this blocks until socat has the read end open.
echo "Starting audio stream server on port 7777..."
socat -u OPEN:/tmp/audio.fifo,nonblock TCP-LISTEN:7777,fork,reuseaddr &
STREAM_PID=$!

echo "Starting TCP-to-pipe bridge on port 57120..."
socat -u TCP-LISTEN:57120,reuseaddr,fork OPEN:/tmp/sc_pipe,creat,append &
SOCAT_PID=$!

# Start SuperCollider
echo "Starting SuperCollider..."
export QT_QPA_PLATFORM=offscreen
export QTWEBENGINE_DISABLE_SANDBOX=1

# Load boot_scsynth.scd via SC's startup file so sclang stays in REPL mode
# after boot, reading subsequent commands from stdin (the pipe).
mkdir -p /root/.config/SuperCollider
echo 'thisProcess.interpreter.executeFile("/sc/boot_scsynth.scd");' > /root/.config/SuperCollider/startup.scd

# Open sc_pipe with O_RDWR so sclang's stdin open succeeds immediately.
# Keeping this FD open prevents sclang from ever receiving EOF on stdin.
exec 9<>/tmp/sc_pipe

sclang 2>&1 < /tmp/sc_pipe &
SCLANG_PID=$!

echo ""
echo "SuperCollider audio streaming is running!"
echo "- JACK dummy driver (PID: $JACKD_PID)"
echo "- sclang (PID: $SCLANG_PID)"
echo "- Audio stream on TCP port 7777 (DiskOut -> FIFO -> socat)"
echo "- Send SuperCollider code via TCP port 57120"
echo ""

trap 'kill $SCLANG_PID $JACKD_PID $SOCAT_PID $STREAM_PID 2>/dev/null; rm -f /tmp/sc_pipe /tmp/audio.fifo; exit 0' SIGTERM SIGINT
wait $SCLANG_PID
