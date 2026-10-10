FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Add libwayland-dev, wayland-protocols and libxkbcommon-dev for native support
RUN apt-get update && apt-get install -y \
    git cmake make g++ \
    libsdl2-dev libgtk-3-dev libvpx-dev \
    zlib1g-dev libbz2-dev libjpeg-dev \
    libfluidsynth-dev libgme-dev libopenal-dev \
    libmpg123-dev libsndfile1-dev libwildmidi-dev \
    nasm tar wget \
    libwayland-dev wayland-protocols libxkbcommon-dev \
    libwebp-dev \
    vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

# (The rest of the ZMusic and GZDoom compilation remains the same...)
WORKDIR /tmp/zmusic
# ldconfig registers /usr/local/lib so gzdoom can load libzmusic. Without it
# the game only started under the NVIDIA runtime, whose hook happens to run it.
RUN git clone https://github.com/coelckers/ZMusic.git . && \
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j"$(nproc)" && \
    cmake --install build && \
    ldconfig

WORKDIR /tmp/gzdoom
RUN git clone https://github.com/coelckers/gzdoom.git . && \
    git checkout g4.11.3 && \
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DINCLUDE_INSTALL_DIR=/usr/include && \
    cmake --build build -j"$(nproc)" && \
    cmake --install build

# The container runs as the host user (see docker-compose.yml), whose UID has
# no home in the image. A sticky world-writable one lets any UID keep its
# engine cache there.
WORKDIR /root
RUN rm -rf /tmp/gzdoom /tmp/zmusic && \
    mkdir -m 1777 /home/doom

WORKDIR /games
# Config and saves live in the /config bind mount, independent of $HOME and
# of each engine's default path layout.
ENTRYPOINT ["gzdoom", "-config", "/config/gzdoom.ini", "-savedir", "/config/savegames"]