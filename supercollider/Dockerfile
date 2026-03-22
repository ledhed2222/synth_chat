FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install SuperCollider and dependencies
RUN apt-get update && apt-get install -y \
    supercollider \
    supercollider-server \
    supercollider-ide \
    supercollider-supernova \
    sc3-plugins \
    # Qt and GUI dependencies
    qt5-qmake \
    qtbase5-dev \
    qtwebengine5-dev \
    libqt5webkit5-dev \
    # Audio libraries
    libjack-jackd2-0 \
    jackd2 \
    jack-tools \
    libasound2 \
    alsa-utils \
    # Audio capture
    ffmpeg \
    # Utilities
    bash \
    socat \
    && rm -rf /var/lib/apt/lists/*

# Create directory for SuperCollider files
RUN mkdir -p /sc
WORKDIR /sc

# Configure ALSA to use dummy device
RUN echo "pcm.!default { type plug slave.pcm \"null\" }" > /etc/asound.conf

# Set environment variables for headless operation
ENV QT_QPA_PLATFORM=offscreen
ENV QTWEBENGINE_DISABLE_SANDBOX=1

# Copy our entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 57120/tcp
EXPOSE 7777/tcp

CMD ["/usr/local/bin/entrypoint.sh"]
