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
RUN git clone https://github.com/coelckers/ZMusic.git . && \
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j"$(nproc)" && \
    cmake --install build

WORKDIR /tmp/gzdoom
RUN git clone https://github.com/coelckers/gzdoom.git . && \
    git checkout g4.11.3 && \
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DINCLUDE_INSTALL_DIR=/usr/include && \
    cmake --build build -j"$(nproc)" && \
    cmake --install build

WORKDIR /root
RUN rm -rf /tmp/gzdoom /tmp/zmusic

WORKDIR /games
ENTRYPOINT ["gzdoom"]