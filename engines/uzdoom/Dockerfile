# UZDoom, the maintained GZDoom fork (same engine the macOS launcher uses).
# Debian trixie ships clang-19, the compiler UZDoom's own Linux CI uses for
# its C++20 codebase; the build dependencies mirror that CI's list.
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

ARG UZDOOM_VERSION=5.0.3

# Build toolchain + libraries UZDoom links against. libsndfile/libmpg123 are
# loaded by ZMusic at runtime for OGG/MP3 music (e.g. the IDKFA soundtrack).
# vulkan-tools pulls in the Mesa Vulkan drivers via Recommends (see
# .hadolint.yaml); NVIDIA's driver comes from the container runtime instead.
RUN apt-get update && apt-get install -y \
    ca-certificates git cmake ninja-build clang-19 python3 \
    libsdl2-dev libopenal-dev waylandpp-dev libxkbcommon-dev \
    libwebp-dev libbz2-dev libvpx-dev zlib1g-dev \
    libsndfile1-dev libmpg123-dev \
    vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

# ZMusic is bundled (libraries/ZMusic) and installed as a shared library under
# /usr/local/lib; ldconfig registers it so uzdoom can load it without relying
# on the NVIDIA runtime's hook to rebuild the linker cache.
WORKDIR /tmp/uzdoom
RUN git clone --depth 1 --branch "${UZDOOM_VERSION}" https://github.com/UZDoom/UZDoom.git . && \
    cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=clang-19 -DCMAKE_CXX_COMPILER=clang++-19 && \
    cmake --build build && \
    cmake --install build && \
    ldconfig

# The container runs as the host user (see docker-compose.yml), whose UID has
# no home in the image. A sticky world-writable one lets any UID keep its
# engine cache there.
WORKDIR /root
RUN rm -rf /tmp/uzdoom && \
    mkdir -m 1777 /home/doom

WORKDIR /games
# Config lives in the /config bind mount and saves in /saves (the synced saves
# repo), independent of $HOME and of each engine's default path layout.
# shared.cfg holds the settings every machine shares (see README).
ENTRYPOINT ["uzdoom", "-config", "/config/uzdoom.ini", "-savedir", "/saves", "-exec", "/config/shared.cfg"]
